// Copyright (C) 2023-2026  Lightpanda (Selecy SAS)
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.

const std = @import("std");

const crypto = @import("../sys/libcrypto.zig");

const pem_begin = "-----BEGIN CERTIFICATE-----";
const pem_end = "-----END CERTIFICATE-----";
const russian_trusted_root_pem = @embedFile("certificates/russian_trusted_root_ca.pem");

const russian_trusted_root_der = blk: {
    @setEvalBranchQuota(10_000);
    const body_start = (std.mem.indexOf(u8, russian_trusted_root_pem, pem_begin) orelse
        @compileError("Russian Trusted Root CA PEM header is missing")) + pem_begin.len;
    const body_end = std.mem.indexOfPos(u8, russian_trusted_root_pem, body_start, pem_end) orelse
        @compileError("Russian Trusted Root CA PEM footer is missing");
    const body = russian_trusted_root_pem[body_start..body_end];

    var encoded: [body.len]u8 = undefined;
    var encoded_len: usize = 0;
    for (body) |byte| {
        if (byte == '\r' or byte == '\n') continue;
        encoded[encoded_len] = byte;
        encoded_len += 1;
    }

    const decoder = std.base64.standard.Decoder;
    const der_len = decoder.calcSizeForSlice(encoded[0..encoded_len]) catch |err|
        @compileError(@errorName(err));
    var der: [der_len]u8 = undefined;
    decoder.decode(&der, encoded[0..encoded_len]) catch |err|
        @compileError(@errorName(err));
    break :blk der;
};

pub fn addRussianTrustedRoot(store: *crypto.X509_STORE) !void {
    const der = russian_trusted_root_der[0..];
    var ptr = der.ptr;
    const x509 = crypto.d2i_X509(null, &ptr, @intCast(der.len)) orelse
        return error.InvalidBundledRussianTrustedRoot;
    defer crypto.X509_free(x509);

    if (crypto.X509_STORE_add_cert(store, x509) != 1) {
        return error.FailedToAddBundledRussianTrustedRoot;
    }
}

test "Russian Trusted Root CA fingerprint" {
    const expected = [_]u8{
        0xd2, 0x6d, 0x2d, 0x02, 0x31, 0xb7, 0xc3, 0x9f,
        0x92, 0xcc, 0x73, 0x85, 0x12, 0xba, 0x54, 0x10,
        0x35, 0x19, 0xe4, 0x40, 0x5d, 0x68, 0xb5, 0xbd,
        0x70, 0x3e, 0x97, 0x88, 0xca, 0x8e, 0xcf, 0x31,
    };
    var actual: [std.crypto.hash.sha2.Sha256.digest_length]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(&russian_trusted_root_der, &actual, .{});
    try std.testing.expectEqualSlices(u8, &expected, &actual);
}

test "Russian Trusted Root CA can be added more than once" {
    const store = crypto.X509_STORE_new() orelse return error.FailedToCreateX509Store;
    defer crypto.X509_STORE_free(store);

    try addRussianTrustedRoot(store);
    try addRussianTrustedRoot(store);
}
