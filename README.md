#  Photoshoot Import

This macOS application is designed to import photos (of any format) from one source folder to a
destination folder, renaming files and putting them into subfolders according to the structure of
your choosing.

It relies on ExifTool, to access the photos' metadata so they can be used
in the process.

It was developed on my free time as a mean to play with Swift and The Composable Architecture.
I hope I did them justice.

## Installation

Checkout this repository and [build](#test-and-build) the app with Xcode.

**Photoshoot Import** requires ExifTool, which can be installed using their installer (available for
  download on their [website](https://exiftool.org/)), or via [Homebrew](https://brew.sh/) by typing
  the following command line in a terminal:

`brew install exiftool`

The path to the `exiftool` executable can then be configured in **Photoshoot Import**'s settings,
accessible via the main menu. **Photoshoot Import** will try to guess the location of the
`exiftool` at launch (it should be `/usr/local/bin/exiftool` if installed via the ExifTool
installer, or `/opt/homebrew/bin` if installed via Homebrew).

## Usage

Importing photos from a shooting requires the following parameters:

 - Source folder: contains all the photos to import (e.g. a memory card)
 - Destination folder: will contain all the imported photos
 - Output format: tells how **Photoshoot Import** shall arrange and rename the imported photos in
   the destination folder
 - Recursive: tells if **Photoshoot Import** shall crawl the source folder recursively for photos to
   import, or if it shall only import photos that sit directly under the source folder
 - Import mode: tells **Photoshoot Import** to either copy the imported files (keeping the originals
   in the source folder) or move them (suppressing the originals from the source folder).

### Output format

**Photoshoot Import**'s magic happens thanks to a useful language that makes use of variables to
  name the folders and imported photos exactly how you want for later processing.

A variable is surrounded by opening and closing `'#'` characters, taking the form `#<variable>#`,
where `<variable>` designate the desired variable.

There are 3 types of variables:

 - `file`: for properties related to the photo as a file on the filesystem,
 - `exif`: for properties contains in the photo's EXIF metadata (if any),
 - `sequence`: for generating unique numbers.

#### File variables

File variables refer to properties of the source file on the filesystem, and start with
`file:<property>`, where `<property>` refers to the desired file property that should be output in
the imported file name or path. 

Examples are given for a file sitting at `folder/subfolder/image.jpg`, that was created on
2024-01-01 12:34:56 and modified on 2024-02-10 01:02:03 on the filesystem:

| Property | Full variable | Description | Value example | |----------|-------------|------| |
`name` | `#file:name#` | The complete, original source file name | `image.jpg` | | `ext`   |
`#file:ext#` | The source file extension | `jpg` | | `namenoext` | `#file:namenoext#` | The source
file name, without extension | `image` | | `path` | `#file:path#` | The path of the source file's
parent folder, relative to the selected source folder | `folder/subfolder/` | | `creationdate` |
`#file:creationdate#` | The date of creation of the file on the filesystem | `20240102` | |
`modificationdate` | `#file:modificationdate#` | The date of last modification of the file on the
filesystem | `20240210` |

For date properties like `creationdate` and `modificationdate`, the date format is `yyyyMMdd` by
default. It can be specified by appending the character `':'` and the desired format to the
property, e.g. `#file:creationdate:yyMM`. See [Date Format Patterns]
(https://www.unicode.org/reports/tr35/tr35-31/tr35-dates.html#Date_Format_Patterns) for available
date patterns.

#### EXIF variables

EXIF variables refer to properties stored in the EXIF metadata of images, and start with
`exif:<property>`, where property can be any EXIF tag name that ExifTool can read. See [EXIF Tags]
(https://exiftool.org/TagNames/EXIF.html) for a complete list.

Some EXIF properties, such as `DateTimeOriginal`, correspond to dates in the format `yyyy:MM:dd
HH:mm:ss`. **Photoshoot Import** can re-format these dates according to your preferences, by
appending the character `':'` and the desired format to the property, e.g.:
`#exif:DateTimeOriginal:yyMM#.jpg`. This will have no effect if the EXIF property cannot be parsed
as a date.

> **Note:** If an EXIF property cannot be found in a file's metada, **Photoshoot Import** inserts an
    empty string in its stead. E.g. the format `Photo #exif:CreateDate#.jpg` will output
    `Photo .jpg` if the `CreateDate` tag is missing in the photo's metadata.

> **Note:** Using EXIF variables when importing a large quantity of photos may yield poor
    performances.

#### Sequence variables

Sequence variables are number sequences generated by **Photoshoot Import**. There are two kinds of
sequences, `global` and `local`. Both start at 1, and both are incremented by 1 for each file
imported, but the local sequence is reset to 1 for each new folder created in the destination folder.

The format of the sequence number can be specified by appending the number of zeros to the
variable. For instance, `#sequence:global:4#` will generate sequence numbers of 4 characters,
padded with 0, from `0001` to `9999`. The default, if unspecified, is 1, i.e. `#sequence:local#`
is equivalent to `#sequence:local:1#`.

For instance, if you import 5 files, 2 JPEG and 3 RAW, and the output format separates JPEG and RAW
files in distinct folders, here's what you will obtain:

Output format: `#file:ext#/#file:namenoext#_#sequence:local#_#sequence:global:4#.#file:ext#`

```
+ JPEG/
    + photo_1_0001.JPEG
    + photo_2_0002.JPEG
+ RAW/
    + photo_1_0003.RAW
    + photo_2_0004.RAW
    + photo_3_0005.RAW
```

#### Constants and path separators

Anything that is not a variable is treated as a constant string, except for `'/'` characters which
are treated as path separators for the creation of folders.

For instance, the output format `import/photos/photo_#file:name#` will generate the following
structure in the destination folder:

```
+ import/
    + photos/
        + photo_<filename>
```

> **Note:** If the evalution of a variable returns a value that contains `'/'` characters, they will
    also be treated as path separators.

### Examples

Organize your photos by the year and month of their capture, renaming them with
a common name and a sequence number:

`#exif:DateTimeOriginal:yyyy#/#exif:DateTimeOriginal:MM#/photo_#sequence:local:4#.#file:ext#`

### Name conflits

The flexibility of the output format allows for a lot of possibilities, including that of importing
two different files into the same folder and with the same name, thus creating a name conflict.

An obvious case of name conflict would occur if you tried to import two photos using the output
format `photo.jpg`, which would cause the two imported photos to be renamed to `photo.jpg` and put
into the same folder, and which is not possible.

**Photoshoot Import** handles name conflicts gracefully, by appending a space followed by a number
  to the name of the imported file (before its extension, if any) if it conflicts with a previously
  imported file.

For instance, if **Photoshoot Import** is told to rename a file to `photo.jpeg` and import it into a
folder where `photo.jpeg` already exists, it will try to import the file by renaming it `photo
1.jpeg`.  If `photo 1.jpeg` also already exists, it will try to import the file by renaming it to
`photo 2.jpeg`, and so on, each time incrementing the number by 1 until the name is finally
available and the file can be imported.

> **Note:** It is preferable to explicitly set a sequence number in the output format, as it can
    avoid lots of failed attemps at writing files on disk, and thus improve performances.

## Test and build

The application can be tested via the following command:

`xcodebuild -scheme PhotoshootImport -target PhotoshootImportTests test`

The app can be built via the following command:

`xcodebuild -scheme PhotoshootImport -target "PhotoshootImport archive -archivePath dist/PhotoshootImport.xcarchive`

The .app will be available at `dist/PhotoshootImport.xcarchive/Products/Applications/PhotoshootImport.app`.

## Credits

**Photoshoot Import** makes use of the following software:
* [ExifTool](https://exiftool.org/) © Phil Harvey
* [ExifTool Swift](https://github.com/hlemai/ExifTool) © Hervé Lemai
* [The Composable Architecture](https://github.com/pointfreeco/swift-composable-architecture) © Point-Free, Inc.

## License

This software is licensed under the BSD 2-Clause license. See [LICENSE](./LICENSE) file.
