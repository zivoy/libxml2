const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Build options
    const build_tools = b.option(bool, "tools", "Build xmllint and xmlcatalog tools") orelse true;
    const dynamic = b.option(bool, "dynamic", "Build dynamic library") orelse false;

    // Feature options - only for explicitly disabling features
    const html = b.option(bool, "html", "Enable HTML parsing") orelse true;
    const c14n = b.option(bool, "c14n", "Enable C14N support") orelse true;
    const catalog = b.option(bool, "catalog", "Enable catalog support") orelse true;
    const debug = b.option(bool, "debug", "Enable debugging support") orelse true;
    const ftp = b.option(bool, "ftp", "Enable FTP support") orelse false;
    const http = b.option(bool, "http", "Enable HTTP support") orelse false;
    const iso8859x = b.option(bool, "iso8859x", "Enable ISO8859X support") orelse true;
    const legacy = b.option(bool, "legacy", "Enable deprecated APIs") orelse false;
    const modules = b.option(bool, "modules", "Enable dynamic module loading") orelse true;
    const output = b.option(bool, "output", "Enable serialization support") orelse true;
    const pattern = b.option(bool, "pattern", "Enable pattern support") orelse true;
    const push = b.option(bool, "push", "Enable push parser") orelse true;
    const reader = b.option(bool, "reader", "Enable xmlReader API") orelse true;
    const regexps = b.option(bool, "regexps", "Enable regular expressions") orelse true;
    const relaxng = b.option(bool, "relaxng", "Enable Relax-NG support") orelse true;
    const sax1 = b.option(bool, "sax1", "Enable SAX1 API") orelse true;
    const schemas = b.option(bool, "schemas", "Enable XML Schemas support") orelse true;
    const schematron = b.option(bool, "schematron", "Enable Schematron support") orelse true;
    const tree = b.option(bool, "tree", "Enable tree manipulation APIs") orelse true;
    const valid = b.option(bool, "valid", "Enable DTD validation") orelse true;
    const writer = b.option(bool, "writer", "Enable xmlWriter API") orelse true;
    const xinclude = b.option(bool, "xinclude", "Enable XInclude support") orelse true;
    const xpath = b.option(bool, "xpath", "Enable XPath support") orelse true;
    const xptr = b.option(bool, "xptr", "Enable XPointer support") orelse true;

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
        .HAVE_LIBHISTORY = @intFromBool(isPosix),
        .HAVE_LIBREADLINE = @intFromBool(isPosix),
        .HAVE_SHLLOAD = @intFromBool(!isPosix),
        .HAVE_STDINT_H = 1,
        .XML_SYSCONFDIR = sysconfdir,
        .XML_THREAD_LOCAL = if (isPosix) "_Thread_local" else "__declspec(thread)",
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

    // Add config header
    libxml2.addConfigHeader(config_h);
    libxml2.root_module.addCMacro("HAVE_CONFIG_H", "1");

    // Feature macros for libxml2
    if (c14n) lib_mod.addCMacro("LIBXML_C14N_ENABLED", "1");
    if (catalog) lib_mod.addCMacro("LIBXML_CATALOG_ENABLED", "1");
    if (debug) lib_mod.addCMacro("LIBXML_DEBUG_ENABLED", "1");
    if (ftp) lib_mod.addCMacro("LIBXML_FTP_ENABLED", "1");
    if (html) lib_mod.addCMacro("LIBXML_HTML_ENABLED", "1");
    if (http) lib_mod.addCMacro("LIBXML_HTTP_ENABLED", "1");
    if (iconv) lib_mod.addCMacro("LIBXML_ICONV_ENABLED", "1");
    if (icu) lib_mod.addCMacro("LIBXML_ICU_ENABLED", "1");
    if (iso8859x) lib_mod.addCMacro("LIBXML_ISO8859X_ENABLED", "1");
    if (legacy) lib_mod.addCMacro("LIBXML_LEGACY_ENABLED", "1");
    if (lzma) lib_mod.addCMacro("LIBXML_LZMA_ENABLED", "1");
    if (modules) lib_mod.addCMacro("LIBXML_MODULES_ENABLED", "1");
    if (output) lib_mod.addCMacro("LIBXML_OUTPUT_ENABLED", "1");
    if (pattern) lib_mod.addCMacro("LIBXML_PATTERN_ENABLED", "1");
    if (push) lib_mod.addCMacro("LIBXML_PUSH_ENABLED", "1");
    if (reader) lib_mod.addCMacro("LIBXML_READER_ENABLED", "1");
    if (regexps) lib_mod.addCMacro("LIBXML_REGEXP_ENABLED", "1");
    if (relaxng) lib_mod.addCMacro("LIBXML_RELAXNG_ENABLED", "1");
    if (sax1) lib_mod.addCMacro("LIBXML_SAX1_ENABLED", "1");
    if (schemas) lib_mod.addCMacro("LIBXML_SCHEMAS_ENABLED", "1");
    if (schematron) lib_mod.addCMacro("LIBXML_SCHEMATRON_ENABLED", "1");
    if (threads) lib_mod.addCMacro("LIBXML_THREAD_ENABLED", "1");
    if (tree) lib_mod.addCMacro("LIBXML_TREE_ENABLED", "1");
    if (valid) lib_mod.addCMacro("LIBXML_VALID_ENABLED", "1");
    if (writer) lib_mod.addCMacro("LIBXML_WRITER_ENABLED", "1");
    if (xinclude) lib_mod.addCMacro("LIBXML_XINCLUDE_ENABLED", "1");
    if (xpath) lib_mod.addCMacro("LIBXML_XPATH_ENABLED", "1");
    if (xptr) lib_mod.addCMacro("LIBXML_XPTR_ENABLED", "1");
    if (zlib) lib_mod.addCMacro("LIBXML_ZLIB_ENABLED", "1");

    // Install headers
    libxml2.installHeadersDirectory(libxml2_upstream.path("include"), ".", .{});
    libxml2.installConfigHeader(config_h);

    // Add core source files
    libxml2.addCSourceFiles(.{
        .root = libxml2_upstream.path("."),
        .files = &core_sources,
        .flags = &common_cflags,
    });

    // Conditionally add feature-specific source files
    if (html) {
        libxml2.addCSourceFiles(.{
            .root = libxml2_upstream.path("."),
            .files = &html_sources,
            .flags = &common_cflags,
        });
    }

    if (c14n) {
        libxml2.addCSourceFile(.{
            .file = libxml2_upstream.path("c14n.c"),
            .flags = &common_cflags,
        });
    }

    if (catalog) {
        libxml2.addCSourceFile(.{
            .file = libxml2_upstream.path("catalog.c"),
            .flags = &common_cflags,
        });
    }

    if (debug) {
        libxml2.addCSourceFile(.{
            .file = libxml2_upstream.path("debugXML.c"),
            .flags = &common_cflags,
        });
    }

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
    }

    if (modules) {
        libxml2.addCSourceFile(.{
            .file = libxml2_upstream.path("xmlmodule.c"),
            .flags = &common_cflags,
        });
    }

    if (pattern) {
        libxml2.addCSourceFile(.{
            .file = libxml2_upstream.path("pattern.c"),
            .flags = &common_cflags,
        });
    }

    if (reader) {
        libxml2.addCSourceFile(.{
            .file = libxml2_upstream.path("xmlreader.c"),
            .flags = &common_cflags,
        });
    }

    if (regexps) {
        libxml2.addCSourceFiles(.{
            .root = libxml2_upstream.path("."),
            .files = &regexp_sources,
            .flags = &common_cflags,
        });
    }

    if (relaxng) {
        libxml2.addCSourceFile(.{
            .file = libxml2_upstream.path("relaxng.c"),
            .flags = &common_cflags,
        });
    }

    if (schemas) {
        libxml2.addCSourceFiles(.{
            .root = libxml2_upstream.path("."),
            .files = &schema_sources,
            .flags = &common_cflags,
        });
    }

    if (schematron) {
        libxml2.addCSourceFile(.{
            .file = libxml2_upstream.path("schematron.c"),
            .flags = &common_cflags,
        });
    }

    if (threads) {
        libxml2.addCSourceFile(.{
            .file = libxml2_upstream.path("threads.c"),
            .flags = &common_cflags,
        });
        if (isPosix) {
            libxml2.linkSystemLibrary2("pthread", .{});
        }
    }

    if (writer) {
        libxml2.addCSourceFile(.{
            .file = libxml2_upstream.path("xmlwriter.c"),
            .flags = &common_cflags,
        });
    }

    if (xinclude) {
        libxml2.addCSourceFile(.{
            .file = libxml2_upstream.path("xinclude.c"),
            .flags = &common_cflags,
        });
    }

    if (xpath) {
        libxml2.addCSourceFile(.{
            .file = libxml2_upstream.path("xpath.c"),
            .flags = &common_cflags,
        });
    }

    if (xptr) {
        libxml2.addCSourceFiles(.{
            .root = libxml2_upstream.path("."),
            .files = &xptr_sources,
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

    if (!isPosix) {
        libxml2.linkSystemLibrary2("ws2_32", .{});
    }

    if (modules and isPosix) {
        libxml2.linkSystemLibrary2("dl", .{});
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

// Core source files that are always included
const core_sources = [_][]const u8{
    "buf.c",
    "chvalid.c",
    "dict.c",
    "encoding.c",
    "entities.c",
    "error.c",
    "globals.c",
    "hash.c",
    "list.c",
    "parser.c",
    "parserInternals.c",
    "SAX.c",
    "SAX2.c",
    "tree.c",
    "uri.c",
    "valid.c",
    "xmlIO.c",
    "xmlmemory.c",
    "xmlsave.c",
    "xmlstring.c",
    "xmlunicode.c",
};

// HTML-specific sources
const html_sources = [_][]const u8{
    "HTMLparser.c",
    "HTMLtree.c",
};

// Regular expression sources
const regexp_sources = [_][]const u8{
    "xmlregexp.c",
};

// Schema-specific sources
const schema_sources = [_][]const u8{
    "xmlschemas.c",
    "xmlschemastypes.c",
};

// XPointer sources
const xptr_sources = [_][]const u8{
    "xlink.c",
    "xpointer.c",
};

// Common C flags
const common_cflags = [_][]const u8{
    "-Wall",
    "-Wno-unused-parameter",
    "-Wno-missing-field-initializers",
};
