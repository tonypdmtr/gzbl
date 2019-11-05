# gzbl

Bootloader for Motorola/Freescale/NXP MC68HC908GZ60

## Terminology

### Monitor loader

Monitor loader is a PC side software which can update program memory of an empty (virgin) microcontroller.
Disadvantages are it needs special hardware interface and slow.
I have already written such a software for GZ family. [See here.](https://github.com/butyi/gzml/)

### Bootloader

Bootloader is embedded side software in the microcontroller,
which can receive data from once a hardware interface and write data into own program memory.
This software needs to be downloaded into microcontroller only once by a monitor loader.

### Downloader

Downloader is PC side software. The communication partner of Bootloader.
It can send the pre-compiled software (or any other data) to data to microcontroller through the supported hardware interface.

## Hardware interface

This bootloader uses SCI port for communication. This is an assyncron serial port, so called RS232.
This port so widely used known, that even if this port is not standard on personal computers,
can be purchased easily as a USB-SERIAL interface.

Baud rate of interface is 57600. 8 bits. No parity.

## Binary download

Main function of bootloader is to be able to (re-)download easily and fast the user software.
The user software means the main function of the embedded system.
After power on the bootloader is started. It waits for 1 sec for connection attempt.
If there was no trial to use bootloader services, it calls the user (main) software.
If there is not yet user software downloaded, execution remains in the bootloader,
and bootloader waits for download attempt for infinite.

for binary download, first a connection have to be done.
The connection procedure is, that the downloader periodically sends four 0x1C character as connection attempt.
While the bootloader is running, it waits for these four consecutive bytes, and if bootloader receive,
it sends back connection acknoledgement. This is four consecutive 0x3E bytes.

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
- Error code.

Error code values and meanings
- 0 - No error
- 1 - Checksum error
- 2 - Address error (Bootloader code range are is prohibited to be changed)
- 3 - Timeout error
- 4 - Length is zero
- 5 - Length is too high (>128)
- 6 - Out of page (page overflow from given Address with the given Length)

## Terminal

While bootloader is running, if 't' character is received, bootloader starts a simple terminal software.
This is helpful during debugging user software development.

Terminal functions

- Help for terminal.
- Dump 256 bytes of memory. Sub services are Previous, Again and Next 256 bytes.
- Write hexa data into Flash memory.
- Write simple text into Flash memory.
- Erase page.

Terminal have 8s timeout. If you don't push any button for 8s, Terminal will exit to not block calling of user software.
Push '?' for help. Terminal applies echo for every pushed character to be visible which were already pushed.
Write is page based here also, so it is not supported to write through on page borders.
Bootloader memory range manipulation is prohibited from here too.

## Compile

Just call `asm8 gzbl.asm`.
gzbl.s19 will be ready to download by [monitor loader](https://github.com/butyi/gzml/).

## License

This is free. You can do anything you want with it.
While I am using Linux, I got so many support from free projects, I am happy if I can help for the community.

## Keywords

Motorola, Freescale, NXP, MC68HC908GZ60, 68HC908GZ60, HC908GZ60, MC908GZ60, 908GZ60, HC908GZ48, HC908GZ32, HC908GZ, 908GZ

###### 2019 Janos Bencsik
