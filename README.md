# LibXML2

This is [libxml2](https://gitlab.gnome.org/GNOME/libxml2) packaged using the Zig build system.

This project requires Zig version `0.15.1` or higher.

## Options

You can set these options when importing as a dependency with `b.dependency("libxml2", .{ option=value })` or when building directly with `zig build -Doption=value`.

| Option Name  | Default | Description                                      |
|--------------|:-------:|--------------------------------------------------|
| dynamic      | false   | Build the library as a shared (dynamic) library  |
| tools        | true    | Build CLI tools (xmllint and xmlcatalog)         |
| history      | true    | Enable libhistory support (optional for tools)   |
| readline     | true    | Enable libreadline support (required for tools)  |
| ftp          | false   | Enable FTP support                               |
| http         | false   | Enable HTTP support                              |
| legacy       | false   | Enable deprecated APIs                           |
| sax1         | false   | Enable SAX1 API (requires legacy)                |
| modules      | true    | Enable dynamic module loading                    |
| zlib         | true    | Enable zlib compression                          |
| lzma         | false   | Enable LZMA compression                          |
| icu          | false   | Enable ICU support                               |
| sysconfdir   | Platform-specific | System configuration directory         |
