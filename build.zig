const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Build options
    const build_tools = b.option(bool, "tools", "Build xmllint and xmlcatalog tools") orelse true;
    const dynamic = b.option(bool, "dynamic", "Build dynamic library") orelse false;

    // Feature options - only for features that conditionally compile code
    const ftp = b.option(bool, "ftp", "Enable FTP support") orelse false;
    const http = b.option(bool, "http", "Enable HTTP support") orelse false;
    const legacy = b.option(bool, "legacy", "Enable deprecated APIs") orelse false;
    const sax1 = b.option(bool, "sax1", "Enable SAX1 API (requires legacy)") orelse false;
    const modules = b.option(bool, "modules", "Enable dynamic module loading") orelse true;

    // Optional compression/encoding libraries
    const zlib = b.option(bool, "zlib", "Enable zlib compression") orelse true;
    const lzma = b.option(bool, "lzma", "Enable LZMA compression") orelse false;
    const icu = b.option(bool, "icu", "Enable ICU support") orelse false;

    // Get upstream dependency
    const libxml2_upstream = b.dependency("libxml2_upstream", .{});

    const t = target.result;
    const isPosix = t.os.tag != .windows;

    // Auto-detect features based on platform
    const threads = isPosix;
    const iconv = isPosix;

    const libhistory = b.option(bool, "history", "Enable libhistory") orelse isPosix;
    const libreadline = b.option(bool, "readline", "Enable libreadline") orelse isPosix;

    // Determine sysconfdir based on prefix
    const sysconfdir = b.option([]const u8, "sysconfdir", "System configuration directory") orelse blk: {
        const prefix = b.install_prefix;
        if (!isPosix) {
            break :blk "C:\\etc";
        } else if (std.mem.eql(u8, prefix, "/usr")) {
            break :blk "/etc";
        } else {
            break :blk b.fmt("{s}/etc", .{prefix});
        }
    };

    // Create minimal config header (only what config.h.cmake.in actually uses)
    const config_h = b.addConfigHeader(.{
        .style = .{ .cmake = libxml2_upstream.path("config.h.cmake.in") },
        .include_path = "config.h",
    }, .{
        .HAVE_DECL_GETENTROPY = @intFromBool(isPosix),
        .HAVE_DECL_GLOB = @intFromBool(isPosix),
        .HAVE_DECL_MMAP = @intFromBool(isPosix),
        .HAVE_FUNC_ATTRIBUTE_DESTRUCTOR = @intFromBool(isPosix),
        .HAVE_DLOPEN = @intFromBool(modules and isPosix),
        .HAVE_LIBHISTORY = @intFromBool(libhistory),
        .HAVE_LIBREADLINE = @intFromBool(libreadline),
        .HAVE_SHLLOAD = @intFromBool(!isPosix),
        .HAVE_STDINT_H = 1,
        .XML_SYSCONFDIR = sysconfdir,
        .XML_THREAD_LOCAL = if (isPosix) "_Thread_local" else "__declspec(thread)",
    });

    // Create xmlversion.h from template
    const module_extension = if (isPosix) ".so" else ".dll";

    const xmlversion_h = b.addConfigHeader(.{
        .style = .{ .cmake = libxml2_upstream.path("include/libxml/xmlversion.h.in") },
        .include_path = "libxml/xmlversion.h",
    }, .{
        .VERSION = "2.16.0",
        .LIBXML_VERSION_NUMBER = 21600,
        .LIBXML_VERSION_EXTRA = "",
        .WITH_THREADS = @intFromBool(threads),
        .WITH_THREAD_ALLOC = @intFromBool(threads),
        // .WITH_TREE = 1,
        .WITH_OUTPUT = 1,
        .WITH_PUSH = 1,
        .WITH_READER = 1,
        .WITH_PATTERN = 1,
        .WITH_WRITER = 1,
        .WITH_SAX1 = @intFromBool(sax1 and legacy),
        // .WITH_FTP = @intFromBool(ftp),
        .WITH_HTTP = @intFromBool(http),
        .WITH_VALID = 1,
        .WITH_HTML = 1,
        // .WITH_LEGACY = @intFromBool(legacy),
        .WITH_C14N = 1,
        .WITH_CATALOG = 1,
        .WITH_XPATH = 1,
        .WITH_XPTR = 1,
        .WITH_XINCLUDE = 1,
        .WITH_ICONV = @intFromBool(iconv),
        .WITH_ICU = @intFromBool(icu),
        .WITH_ISO8859X = 1,
        .WITH_DEBUG = 1,
        // .WITH_MEM_DEBUG = 0,
        // .WITH_RUN_DEBUG = 0,
        .WITH_REGEXPS = 1,
        .WITH_RELAXNG = 1,
        .WITH_SCHEMAS = 1,
        .WITH_SCHEMATRON = 1,
        .WITH_MODULES = @intFromBool(modules),
        .MODULE_EXTENSION = module_extension,
        .WITH_ZLIB = @intFromBool(zlib),
        // .WITH_LZMA = @intFromBool(lzma),
    });

    // Create library
    const lib_mod = b.createModule(.{
        .target = target,
        .optimize = optimize,
        .link_libc = true,
        .pic = true,
    });

    const libxml2 = b.addLibrary(.{
        .name = "xml2",
        .root_module = lib_mod,
        .linkage = if (dynamic) .dynamic else .static,
    });

    // Add include paths
    lib_mod.addIncludePath(libxml2_upstream.path("include"));
    lib_mod.addIncludePath(libxml2_upstream.path("."));

    // Add config headers
    libxml2.addConfigHeader(config_h);
    libxml2.addConfigHeader(xmlversion_h);
    libxml2.root_module.addCMacro("HAVE_CONFIG_H", "1");

    // Install headers
    libxml2.installHeadersDirectory(libxml2_upstream.path("include"), ".", .{});
    libxml2.installConfigHeader(config_h);
    libxml2.installConfigHeader(xmlversion_h);

    // Add core source files
    libxml2.addCSourceFiles(.{
        .root = libxml2_upstream.path("."),
        .files = &core_sources,
        .flags = &common_cflags,
    });

    // Conditionally add optional source files
    if (ftp) {
        libxml2.addCSourceFile(.{
            .file = libxml2_upstream.path("nanoftp.c"),
            .flags = &common_cflags,
        });
    }

    if (http) {
        libxml2.addCSourceFile(.{
            .file = libxml2_upstream.path("nanohttp.c"),
            .flags = &common_cflags,
        });
    }

    if (legacy) {
        libxml2.addCSourceFile(.{
            .file = libxml2_upstream.path("legacy.c"),
            .flags = &common_cflags,
        });
        if (sax1) {
            libxml2.addCSourceFile(.{
                .file = libxml2_upstream.path("SAX.c"),
                .flags = &common_cflags,
            });
        }
    }

    if (lzma) {
        libxml2.addCSourceFile(.{
            .file = libxml2_upstream.path("xzlib.c"),
            .flags = &common_cflags,
        });
    }

    // Link external libraries
    if (zlib) {
        if (b.systemIntegrationOption("z", .{})) {
            libxml2.linkSystemLibrary2("z", .{});
        } else {
            if (b.lazyDependency("zlib", .{})) |zlb| {
                libxml2.linkLibrary(zlb.artifact("z"));
            }
        }
    }

    if (lzma) {
        libxml2.linkSystemLibrary2("lzma", .{});
    }

    if (iconv and (t.os.tag == .macos or t.os.tag.isBSD())) {
        // iconv might need separate library on macOS/BSD
        libxml2.linkSystemLibrary2("iconv", .{ .needed = false });
    }

    if (icu) {
        libxml2.linkSystemLibrary2("icuuc", .{});
        libxml2.linkSystemLibrary2("icudata", .{});
    }

    if (threads and isPosix) {
        libxml2.linkSystemLibrary2("pthread", .{});
    }

    if (isPosix and modules) {
        libxml2.linkSystemLibrary2("dl", .{});
    }

    if (!isPosix) {
        libxml2.linkSystemLibrary2("ws2_32", .{});
    }

    if (libreadline) {
        libxml2.linkSystemLibrary2("readline", .{});
    }

    if (libhistory) {
        libxml2.linkSystemLibrary2("history", .{});
    }

    b.installArtifact(libxml2);

    // Build tools
    if (build_tools) {
        const xmllint = b.addExecutable(.{
            .name = "xmllint",
            .root_module = b.createModule(.{
                .target = target,
                .optimize = optimize,
                .link_libc = true,
            }),
        });
        xmllint.linkLibrary(libxml2);
        xmllint.addCSourceFile(.{
            .file = libxml2_upstream.path("xmllint.c"),
            .flags = &common_cflags,
        });
        b.installArtifact(xmllint);

        const xmlcatalog = b.addExecutable(.{
            .name = "xmlcatalog",
            .root_module = b.createModule(.{
                .target = target,
                .optimize = optimize,
                .link_libc = true,
            }),
        });
        xmlcatalog.linkLibrary(libxml2);
        xmlcatalog.addCSourceFile(.{
            .file = libxml2_upstream.path("xmlcatalog.c"),
            .flags = &common_cflags,
        });
        b.installArtifact(xmlcatalog);
    }
}

// Core source files that are always included (from meson.build)
const core_sources = [_][]const u8{
    "buf.c",
    "c14n.c",
    "catalog.c",
    "chvalid.c",
    "debugXML.c",
    "dict.c",
    "encoding.c",
    "entities.c",
    "error.c",
    "globals.c",
    "hash.c",
    "HTMLparser.c",
    "HTMLtree.c",
    "list.c",
    "parser.c",
    "parserInternals.c",
    "pattern.c",
    "relaxng.c",
    "SAX2.c",
    "schematron.c",
    "threads.c",
    "tree.c",
    "uri.c",
    "valid.c",
    "xinclude.c",
    "xlink.c",
    "xmlIO.c",
    "xmlmemory.c",
    "xmlmodule.c",
    "xmlreader.c",
    "xmlregexp.c",
    "xmlsave.c",
    "xmlschemas.c",
    "xmlschemastypes.c",
    "xmlstring.c",
    // "xmlunicode.c",
    "xmlwriter.c",
    "xpath.c",
    "xpointer.c",
};

// Common C flags
const common_cflags = [_][]const u8{
    "-Wall",
    "-Wno-unused-parameter",
    "-Wno-missing-field-initializers",
};
