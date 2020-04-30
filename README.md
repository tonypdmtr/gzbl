# gzbl

Bootloader for Motorola/Freescale/NXP MC68HC908GZ60

## Terminology

### Monitor loader

Monitor loader is a PC side software which can update program memory of an
empty (virgin) microcontroller.
Disadvantages are it needs special hardware interface and it is slow.
I have already written such software for the GZ family.
[See here.](https://github.com/butyi/gzml/)

### Bootloader

Bootloader is software embedded in the microcontroller, which can receive data
from a hardware interface and write it into its own program memory.
This software needs to be programmed into the microcontroller only once by a
monitor loader.

### Downloader

Downloader is PC side software. The communication partner of Bootloader.
It can send the pre-compiled software (or any other data) to data to
microcontroller through the supported hardware interface.

## Hardware interface

This bootloader uses SCI for communication. This is an asynchronous serial port
which when level translated to 12V is called RS232.
This port so widely known and used that even if it's missing on some personal
computers, it can be purchased easily as a add-on USB-to-SERIAL interface.

Serial interface is set for 57600 bps, 8-N-1 operation.

## Binary download

<<<<<<< HEAD
Main function of bootloader is to be able to (re-)download easily and fast the user software.
The user software means the main function of the embedded system.
After power on the bootloader is started. It waits for 1 sec for connection attempt.
If there was no trial to use bootloader services, it calls the user (main) software.
If there is not yet user software downloaded, execution remains in the bootloader,
and bootloader waits for download attempt for infinite.

for binary download, first a connection have to be done.
The connection procedure is, that the downloader periodically sends four 0x1C character as connection attempt.
While the bootloader is running, it waits for these four consecutive bytes, and if bootloader receive,
it sends back connection acknoledgement. This is four consecutive 0xE3 bytes.

If connection was successfull, the bootloader waits for data frames. 
Once a data frame is received and proceeded, bootloader sends a response about the data frame. 
Answer contains error code, which informs downloader if frame data was successfully written into program memory of microcontroller ot not.
Based on the answer, in case of error downloader can repeat the previous frame or in case of successfull write, send the next frame.

As you may know, Flash program memory always consists of pages. Page is the smalest part of memory what can be erased separately.
This means, if we want to change one byte in Flash program memory, we need to save the page data into RAM, erase the complete page,
copy back the saved data together with the modified byte.
Therefore my concept is that I always send complete page in a frame. This enables simply bootloader code.

Bootloader is capable to write smaller amount of data than a page. It does the save into RAM and re-wrire into Flash memory.
But it has no any security solution. It means, if a download procedure is corrupt, 
e.g. once a page was failed to be downloaded and was not repeated, it will not be detected by bootloader,
and bootloader calls the corrupt user software.
Therefore it is proposed for downloader, that first erase the start vector of user software and wrire it at the end of successfull
download procedure only. This ensures, that in case of broken download, start vector will be empty, and bootloader will not call the user software.

Let see the frame structure of data frame

- Frame header - Two bytes. 0x56 and 0xAB.
- Data length - Two bytes. High and low byte. Since GZ60 microcontroller has 128 bytes long page, high byte of length is always zero. 
Two byte is just a preparation for DZ60 microcontroller support, which have 768 bytes long pages.
- Address - Two bytes. Start address of data.
- Data - Length number of bytes. This is the data itself to be written into program memory.
- Checksum - One byte. Simple addition without frame header.

Answer structure

- Frame header - Two bytes. 0xBA and 0x65.
- Address - Two bytes. Same address as was in the data frame.
=======
Main function of a bootloader is to be able to (re-)download easily and fast
the user's application, which is the main function of the embedded system.
After power on, the bootloader starts. It waits for 1 sec for connection attempt.
If there was attempt to use bootloader services, it runs the user's application.
If there is no user application loaded, execution remains in the bootloader,
which waits for a download attempt indefinitely.

For binary download, first a connection has to be made.
The connection procedure is that the downloader periodically sends four 0x1C
characters as a connection attempt.
While the bootloader is running, it waits for these four consecutive bytes, and
if received, it sends back a connection acknowledgement. This is made of four
consecutive 0xE3 bytes.

If the connection was successful, the bootloader waits for data frames.
Once a data frame is received and processed, the bootloader sends a response
about that data frame.
This response contains an error code, which informs the downloader whether the
data frame was successfully written into the program memory of the
microcontroller, or not.
In case of error, the downloader can repeat the previous data frame, and in
case of a successful write, send the next frame.

As you may know, Flash program memory always consists of pages. Page is the
smallest part of Flash memory that can be erased independently.
This means, if we want to change one byte in the Flash program memory, we need
to first save the page data into RAM, erase the complete page, and then copy
back the saved data together with the modified byte.
Therefore, my concept is that I always send complete page in a frame. This
allows for simpler bootloader code.

The bootloader is capable of writing smaller amounts of data than a full page.
It first saves data into RAM and then re-writes it into Flash memory.
But it is an insecure solution.  That is, if a download procedure is corrupted,
e.g. once a page failed to download and not repeated, it will not be detected
by the bootloader, and the bootloader will eventually run a corrupted user
application.
Therefore, it is proposed for the downloader that it first erases the start
vector of the user software, and writes it again at the end of a successful
download procedure only. This ensures, that in case of broken download, the
reset vector will be empty, and the bootloader will not attempt to run the user
application.

Let's see the frame structure of a data frame.

- Frame header - Two bytes, 0x56 and 0xAB.
- Data length - Two bytes, high and low.  Since the GZ60 microcontroller has
  128 byte long page, high byte of length is always zero.
  Two bytes are for future DZ60 microcontroller support, which has 768 byte
  long pages.
- Address - Two bytes indicating the data start address.
- Data - Length number of bytes. This is the data to be written into the
  program memory.
- Checksum - One byte derived from a simple addition without the frame header.

Answer structure:

- Frame header - Two bytes, 0xBA and 0x65.
- Address - Two bytes, same as in the data frame.
>>>>>>> 0c5a3a4a8732ce47dd07efc625412e1dba429e2f
- Error code.

Error code values and meanings:

- 0 - No error
- 1 - Checksum error
- 2 - Address error (Bootloader occupied range is prohibited to change)
- 3 - Timeout error
- 4 - Zero length
- 5 - Length is too high (>128)
- 6 - Out of page bounds (page overflow from given Address with given Length)

## Terminal

While the bootloader is running, if a 't' character is received, the bootloader
starts a simple terminal software.
This is helpful during development for debugging the user's application.

Terminal functions

- Help for terminal.
- Dump 256 bytes of memory. Sub services are Previous, Again, and Next 256 bytes.
- Write hexadecimal data into Flash memory.
- Write simple text into Flash memory.
- Erase page.

Terminal has an 8 second timeout. If you don't press any key for 8 seconds,
the Terminal will exit so as to not block running the user's application.

Press '?' for help. Terminal echoes each received character for confirmation.
Write is page based here also, so it is not allowed to write across page boundaries.
Bootloader memory range manipulation is also prohibited from here.

## Compile (Assemble)

Just run `asm8 gzbl.asm`.
gzbl.s19 will be ready to download by [monitor loader](https://github.com/butyi/gzml/).

## License

This is free software. You can do anything you want with it.
While I've been using Linux, I got so much support from free projects, I am happy if I can contibute back to the community.

## Keywords

Motorola, Freescale, NXP, MC68HC908GZ60, 68HC908GZ60, HC908GZ60, MC908GZ60, 908GZ60, HC908GZ48, HC908GZ32, HC908GZ, 908GZ

###### 2019 Janos Bencsik
