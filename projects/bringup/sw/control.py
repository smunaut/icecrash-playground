#!/usr/bin/env python3

import binascii
import random
import serial
import sys
import time


# ----------------------------------------------------------------------------
# Serial commands
# ----------------------------------------------------------------------------

class WishboneInterface(object):

	COMMANDS = {
		'SYNC' : 0,
		'REG_ACCESS' : 1,
		'DATA_SET' : 2,
		'DATA_GET' : 3,
		'AUX_CSR' : 4,
	}

	def __init__(self, port):
		self.ser = ser = serial.Serial()
		ser.port = port
		ser.baudrate = 4000000
		ser.stopbits = 2
		ser.timeout = 0.1
		ser.open()

		if not self.sync():
			raise RuntimeError("Unable to sync")

	def sync(self):
		for i in range(10):
			self.ser.write(b'\x00')
			d = self.ser.read(4)
			if (len(d) == 4) and (d == b'\xca\xfe\xba\xbe'):
				return True
		return False

	def write(self, addr, data):
		cmd_a = ((self.COMMANDS['DATA_SET']   << 36) | data).to_bytes(5, 'big')
		cmd_b = ((self.COMMANDS['REG_ACCESS'] << 36) | addr).to_bytes(5, 'big')
		self.ser.write(cmd_a + cmd_b)

	def read(self, addr):
		cmd_a = ((self.COMMANDS['REG_ACCESS'] << 36) | (1<<20) | addr).to_bytes(5, 'big')
		cmd_b = ((self.COMMANDS['DATA_GET']   << 36)).to_bytes(5, 'big')
		self.ser.write(cmd_a + cmd_b)
		d = self.ser.read(4)
		if len(d) != 4:
			raise RuntimeError('Comm error')
		return int.from_bytes(d, 'big')

	def read_burst(self, addr, burst_len, adv=4):
		req_addr = addr
		ofs  = 0
		resp = []

		while len(resp) < burst_len:
			# Anything left to request ?
			if ofs < burst_len:
				# Issue commands
				cmd_a = ((self.COMMANDS['REG_ACCESS'] << 36) | (1<<20) | (addr + ofs)).to_bytes(5, 'big')
				cmd_b = ((self.COMMANDS['DATA_GET']   << 36)).to_bytes(5, 'big')
				self.ser.write(cmd_a + cmd_b)

				# Next
				ofs += 1

			# If we're in advance, read back
			if ofs > adv:
				d = self.ser.read(4)
				if len(d) != 4:
					raise RuntimeError('Comm error')
				resp.append( int.from_bytes(d, 'big') )

		return resp

	def aux_csr(self, value):
		cmd = ((self.COMMANDS['AUX_CSR'] << 36) | value).to_bytes(5, 'big')
		self.ser.write(cmd)


# ----------------------------------------------------------------------------
# QSPI controller
# ----------------------------------------------------------------------------

class QSPIController(object):

	CORE_REGS = {
		'csr': 0,
		'rf': 3,
	}

	def __init__(self, intf, base, cs=0):
		self.intf = intf
		self.base = base
		self.cs = cs
		self._end()

	def _write(self, reg, val):
		self.intf.write(self.base + self.CORE_REGS.get(reg, reg), val)

	def _read(self, reg):
		return self.intf.read(self.base + self.CORE_REGS.get(reg, reg))

	def _begin(self):
		# Request external control
		self._write('csr', 0x00000004 | (self.cs << 4))
		self._write('csr', 0x00000002 | (self.cs << 4))

	def _end(self):
		# Release external control
		self._write('csr', 0x00000004)

	def spi_xfer(self, tx_data, dummy_len=0, rx_len=0):
		# Start transaction
		self._begin()

		# Total length
		l = len(tx_data) + rx_len + dummy_len

		# Prep buffers
		tx_data = tx_data + bytes( ((l + 3) & ~3) - len(tx_data) )
		rx_data = b''

		# Run
		while l > 0:
			# Word and command
			w = int.from_bytes(tx_data[0:4], 'big')
			c = 0x13 if l >= 4 else (0x10 + l - 1)
			s = 0 if l >= 4 else 8*(4-l)

			# Issue
			self._write(c, w);
			w = self._read('rf')

			# Get RX
			rx_data = rx_data + ((w << s) & 0xffffffff).to_bytes(4, 'big')

			# Next
			l = l - 4
			tx_data = tx_data[4:]

		# End transaction
		self._end()

		# Return interesting part
		return rx_data[-rx_len:]


	def _qpi_tx(self, data, command=False):
		while len(data):
			# Base command
			cmd = 0x1c if command else 0x18

			# Grab chunk
			word = data[0:4]
			data = data[4:]

			cmd |= len(word) - 1
			word = word + bytes(-len(word) & 3)

			# Transmit
			self._write(cmd, int.from_bytes(word, 'big'));

	def _qpi_rx(self, l):
		data = b''

		while l > 0:
			# Issue read
			wl = 4 if l >= 4 else l
			cmd = 0x14 | (wl-1)
			self._write(cmd, 0)
			word = self._read('rf')

			# Accumulate
			data = data + (word & (0xffffffff >> (8*(4-wl)))).to_bytes(wl, 'big')

			# Next
			l = l - 4

		return data

	def qpi_xfer(self, cmd=b'', payload=b'', dummy_len=0, rx_len=0):
		# Start transaction
		self._begin()

		# TX command
		if cmd:
			self._qpi_tx(cmd, True)

		# TX payload
		if payload:
			self._qpi_tx(payload, False)

		# Dummy
		if dummy_len:
			self._qpi_rx(dummy_len)

		# RX payload
		if rx_len:
			rv = self._qpi_rx(rx_len)
		else:
			rv = None

		# End transaction
		self._end()

		return rv


# ----------------------------------------------------------------------------
# I2C master
# ----------------------------------------------------------------------------

class I2CMaster(object):

	CMD_START = 0 << 12
	CMD_STOP  = 1 << 12
	CMD_WRITE = 2 << 12
	CMD_READ  = 3 << 12

	def __init__(self, intf, base=0):
		self.intf = intf
		self.base = base

	def _wait(self):
		while True:
			v = self.intf.read(self.base)
			if v & (1 << 31):
				break
		return v & 0x1ff;

	def start(self):
		self.intf.write(self.base, self.CMD_START)
		self._wait()

	def stop(self):
		self.intf.write(self.base, self.CMD_STOP)
		self._wait()

	def write(self, data):
		self.intf.write(self.base, self.CMD_WRITE | (data & 0xff))
		return bool(self._wait() & (1 << 8))

	def read(self, ack):
		self.intf.write(self.base, self.CMD_READ | ((1 << 8) if ack else 0))
		return self._wait() & 0xff

	def write_reg(self, dev, reg, val):
		self.start()
		self.write(dev)
		self.write(reg)
		self.write(val)
		self.stop()

	def read_reg(self, dev, reg):
		self.start()
		self.write(dev)
		self.write(reg)
		self.start()
		self.write(dev|1)
		v = self.read(True)
		self.stop()
		return v



# --------------------------------------------------------------------------------

def hexdump(x):
	return binascii.b2a_hex(x).decode('utf-8')


def poll_gamepad_cont(wbi):
	# Enable
	wbi.write(0x10000, 1)

	# Poll
	pv = None

	while True:
		# Read value
		rv = [ wbi.read(0x10000 + i) & 0xfff for i in range(4) ]

		# Display if changed
		if pv != rv:
			fv = [f"{rv[i]:012b}" for i in range(4)]
			print("\t".join(fv))

		pv = rv

		# Wait a bit
		time.sleep(0.05)


def poll_gamepad_od(wbi):
	# Poll
	pv = None

	while True:
		# Request value
		wbi.write(0x10000, 0)

		# Wait a bit
		time.sleep(0.05)

		# Read value
		rv = wbi.read(0x10000) & 0xfff

		if pv != rv:
			print(f"{rv:012b}")

		pv = rv


def main(argv0, port='/dev/ttyACM0'):
	wbi   = WishboneInterface(port=port)
	i2c   = I2CMaster(wbi, 0x00000)
	psram = QSPIController(wbi, 0x10000, cs=1)


	# Mandatory _first_ write to enable TPI
	i2c.write_reg(0x72, 0xc7, 0x00)
	time.sleep(0.1)

	# Probe TPI revision
	chip_id = [
		i2c.read_reg(0x72, 0x1b),
		i2c.read_reg(0x72, 0x1c),
		i2c.read_reg(0x72, 0x1d),
	]
	print(f"[Sil9022] DevID={chip_id[0]:02x}, RevID={chip_id[1]:02x}, TPI={chip_id[2]:02x}")

	# Basic video mode setup
	i2c.write_reg(0x72, 0x00, 0xd0)
	i2c.write_reg(0x72, 0x01, 0x09)

	i2c.write_reg(0x72, 0x02, 0x3c)
	i2c.write_reg(0x72, 0x03, 0x00)

	i2c.write_reg(0x72, 0x04, 0x20)
	i2c.write_reg(0x72, 0x05, 0x03)

	i2c.write_reg(0x72, 0x06, 0x0d)
	i2c.write_reg(0x72, 0x07, 0x02)

	# Disable TMDS output
	i2c.write_reg(0x72, 0x1a, 0x01)

	# Power up transmitter
	i2c.write_reg(0x72, 0x1e, 0x00)	# D0 state = full power up

	# Configure Input Bus and Pixel Repetition
		# 1x, Half-width, Edge=Falling, No repeat
	i2c.write_reg(0x72, 0x08, 0x40)

	i2c.write_reg(0x72, 0x09, 0x00)	# In: 8b RGB
	i2c.write_reg(0x72, 0x0a, 0x00)	# Out: 8b RGB

	i2c.write_reg(0x72, 0x60, 0x00)	# External sync
	i2c.write_reg(0x72, 0x61, 0x00)	# Progressive, H+, V+

	# Setup interrupt service
	i2c.write_reg(0x72, 0x3c, 0x1b)

	# Setup SPDIF automatic mode
	i2c.write_reg(0x72, 0x26, 0x40)

	# Enable TMDS output
	i2c.write_reg(0x72, 0x1a, 0x01)

	# Read audio status
	time.sleep(0.1)
	print("Audio status: %02x" % i2c.read_reg(0x72, 0x24));

	# Controller
	poll_gamepad_cont(wbi)
	#poll_gamepad_od(wbi)


if __name__ == '__main__':
	main(*sys.argv)
