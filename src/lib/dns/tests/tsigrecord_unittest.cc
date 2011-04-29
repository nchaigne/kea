// Copyright (C) 2011  Internet Systems Consortium, Inc. ("ISC")
//
// Permission to use, copy, modify, and/or distribute this software for any
// purpose with or without fee is hereby granted, provided that the above
// copyright notice and this permission notice appear in all copies.
//
// THE SOFTWARE IS PROVIDED "AS IS" AND ISC DISCLAIMS ALL WARRANTIES WITH
// REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF MERCHANTABILITY
// AND FITNESS.  IN NO EVENT SHALL ISC BE LIABLE FOR ANY SPECIAL, DIRECT,
// INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM
// LOSS OF USE, DATA OR PROFITS, WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE
// OR OTHER TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION WITH THE USE OR
// PERFORMANCE OF THIS SOFTWARE.

#include <vector>
#include <sstream>

#include <gtest/gtest.h>

#include <util/buffer.h>

#include <dns/messagerenderer.h>
#include <dns/name.h>
#include <dns/rdataclass.h>
#include <dns/tsig.h>
#include <dns/tsigkey.h>
#include <dns/tsigrecord.h>

#include <dns/tests/unittest_util.h>

using namespace std;
using namespace isc::util;
using namespace isc::dns;
using namespace isc::dns::rdata;
using isc::UnitTestUtil;

namespace {
class TSIGRecordTest : public ::testing::Test {
protected:
    TSIGRecordTest() :
        test_name("www.example.com"), test_mac(16, 0xda),
        test_record(test_name, any::TSIG(TSIGKey::HMACMD5_NAME(), 0x4da8877a,
                                         TSIGContext::DEFAULT_FUDGE,
                                         test_mac.size(), &test_mac[0],
                                         0x2d65, 0, 0, NULL)),
        buffer(0), renderer(buffer)
    {}
    const Name test_name;
    vector<unsigned char> test_mac;
    const TSIGRecord test_record;
    OutputBuffer buffer;
    MessageRenderer renderer;
    vector<unsigned char> data;
};

TEST_F(TSIGRecordTest, getName) {
    EXPECT_EQ(test_name, test_record.getName());
}

TEST_F(TSIGRecordTest, getLength) {
    // 83 = 17 + 26 + 16 + 24
    // len(www.example.com) = 17
    // len(hmac-md5.sig-alg.reg.int) = 26
    // len(MAC) = 16
    // the rest are fixed length fields (24 in total)
    EXPECT_EQ(83, test_record.getLength());
}

TEST_F(TSIGRecordTest, recordToWire) {
    UnitTestUtil::readWireData("tsigrecord_toWire1.wire", data);
    EXPECT_EQ(1, test_record.toWire(renderer));
    EXPECT_PRED_FORMAT4(UnitTestUtil::matchWireData,
                        renderer.getData(), renderer.getLength(),
                        &data[0], data.size());

    // Same test for a dumb buffer
    buffer.clear();
    EXPECT_EQ(1, test_record.toWire(buffer));
    EXPECT_PRED_FORMAT4(UnitTestUtil::matchWireData,
                        buffer.getData(), buffer.getLength(),
                        &data[0], data.size());
}

TEST_F(TSIGRecordTest, recordToOLongToWire) {
    // Rendering the test record requires a room of 83 bytes (see the
    // getLength test).  By setting the limit to 82, it will fail, and
    // the renderer will be marked as "truncated".
    renderer.setLengthLimit(82);
    EXPECT_FALSE(renderer.isTruncated()); // not marked before render attempt
    EXPECT_EQ(0, test_record.toWire(renderer));
    EXPECT_TRUE(renderer.isTruncated());
}

TEST_F(TSIGRecordTest, recordToWireAfterNames) {
    // A similar test but the TSIG RR follows some domain names that could
    // cause name compression inside TSIG.  Our implementation shouldn't
    // compress either owner (key) name or the algorithm name.  This test
    // confirms that.

    UnitTestUtil::readWireData("tsigrecord_toWire2.wire", data);
    renderer.writeName(TSIGKey::HMACMD5_NAME());
    renderer.writeName(Name("foo.example.com"));
    EXPECT_EQ(1, test_record.toWire(renderer));
    EXPECT_PRED_FORMAT4(UnitTestUtil::matchWireData,
                        renderer.getData(), renderer.getLength(),
                        &data[0], data.size());
}

TEST_F(TSIGRecordTest, toText) {
    EXPECT_EQ("www.example.com. 0 ANY TSIG hmac-md5.sig-alg.reg.int. "
              "1302890362 300 16 2tra2tra2tra2tra2tra2g== 11621 NOERROR 0\n",
              test_record.toText());
}

// test operator<<.  We simply confirm it appends the result of toText().
TEST_F(TSIGRecordTest, LeftShiftOperator) {
    ostringstream oss;
    oss << test_record;
    EXPECT_EQ(test_record.toText(), oss.str());
}
} // end namespace
