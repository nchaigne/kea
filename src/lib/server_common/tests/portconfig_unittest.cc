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

#include <server_common/portconfig.h>

#include <cc/data.h>
#include <exceptions/exceptions.h>
#include <asiolink/asiolink.h>
#include <asiodns/asiodns.h>

#include <gtest/gtest.h>
#include <string>

using namespace isc::server_common::portconfig;
using namespace isc::data;
using namespace isc;
using namespace std;
using namespace isc::asiolink;
using namespace isc::asiodns;

namespace {

/// Testcase for parseAddresses call (struct, nobody cares about private here)
struct ParseAddresses : public ::testing::Test {
    AddressList result_;
    void empty(ElementPtr config, const string& name) {
        SCOPED_TRACE(name);
        EXPECT_NO_THROW(result_ = parseAddresses(config, "test"));
        EXPECT_TRUE(result_.empty());
    }
    template<class Exception>
    void invalidTest(const string& json, const string& name) {
        SCOPED_TRACE(name);
        ElementPtr config(Element::fromJSON(json));
        EXPECT_THROW(parseAddresses(config, "test"), Exception) <<
            "Should throw " << typeid(Exception).name();
    }
};

// Parse valid IPv4 address
TEST_F(ParseAddresses, ipv4) {
    ElementPtr config(Element::fromJSON("["
                                        "   {"
                                        "       \"address\": \"192.0.2.1\","
                                        "       \"port\": 53"
                                        "   }"
                                        "]"));
    EXPECT_NO_THROW(result_ = parseAddresses(config, "test"));
    ASSERT_EQ(1, result_.size());
    EXPECT_EQ("192.0.2.1", result_[0].first);
    EXPECT_EQ(53, result_[0].second);
}

// Parse valid IPv6 address
TEST_F(ParseAddresses, ipv6) {
    ElementPtr config(Element::fromJSON("["
                                        "   {"
                                        "       \"address\": \"2001:db8::1\","
                                        "       \"port\": 53"
                                        "   }"
                                        "]"));
    EXPECT_NO_THROW(result_ = parseAddresses(config, "test"));
    ASSERT_EQ(1, result_.size());
    EXPECT_EQ("2001:db8::1", result_[0].first);
    EXPECT_EQ(53, result_[0].second);
}

// Parse multiple addresses at once
// (even the ports are different to see they are not mistaken)
TEST_F(ParseAddresses, multi) {
    ElementPtr config(Element::fromJSON("["
                                        "   {"
                                        "       \"address\": \"2001:db8::1\","
                                        "       \"port\": 53"
                                        "   },"
                                        "   {"
                                        "       \"address\": \"192.0.2.1\","
                                        "       \"port\": 54"
                                        "   }"
                                        "]"));
    EXPECT_NO_THROW(result_ = parseAddresses(config, "test"));
    ASSERT_EQ(2, result_.size());
    EXPECT_EQ("2001:db8::1", result_[0].first);
    EXPECT_EQ(53, result_[0].second);
    EXPECT_EQ("192.0.2.1", result_[1].first);
    EXPECT_EQ(54, result_[1].second);
}

// Parse various versions of empty list
TEST_F(ParseAddresses, empty) {
    empty(Element::fromJSON("[]"), "Empty list");
    empty(ElementPtr(new NullElement), "Null element");
    empty(ElementPtr(), "Null pointer");
}

// Reject invalid configs
TEST_F(ParseAddresses, invalid) {
    invalidTest<TypeError>("{}", "Not a list");
    invalidTest<BadValue>("[{}]", "Empty element");
    invalidTest<TypeError>("[{"
                           "   \"port\": 1.5,"
                           "   \"address\": \"192.0.2.1\""
                           "}]", "Float port");
    invalidTest<BadValue>("[{"
                          "   \"port\": -5,"
                          "   \"address\": \"192.0.2.1\""
                          "}]", "Negative port");
    invalidTest<BadValue>("[{"
                          "   \"port\": 1000000,"
                          "   \"address\": \"192.0.2.1\""
                          "}]", "Port too big");
    invalidTest<IOError>("[{"
                         "   \"port\": 53,"
                         "   \"address\": \"bad_address\""
                         "}]", "Bad address");
}

// Test fixture for installListenAddresses
struct InstallListenAddresses : public ::testing::Test {
    InstallListenAddresses() :
        dnss_(ios_, NULL, NULL, NULL)
    {
        valid_.push_back(AddressPair("127.0.0.1", 5288));
        valid_.push_back(AddressPair("::1", 5288));
        invalid_.push_back(AddressPair("192.0.2.2", 1));
    }
    IOService ios_;
    DNSService dnss_;
    AddressList store_;
    // We should be able to bind to these addresses
    AddressList valid_;
    // But this shouldn't work
    AddressList invalid_;
    // Check that the store_ addresses are the same as expected
    void checkAddresses(const AddressList& expected, const string& name) {
        SCOPED_TRACE(name);

        ASSERT_EQ(expected.size(), store_.size()) <<
            "Different amount of elements, not checking content";
        // Run in parallel trough the vectors
        for (AddressList::const_iterator ei(expected.begin()),
             si(store_.begin()); ei != expected.end(); ++ei, ++si) {
            EXPECT_EQ(ei->first, si->first);
            EXPECT_EQ(ei->second, si->second);
        }
    }
};

// Try switching valid addresses
TEST_F(InstallListenAddresses, valid) {
    // First, bind to the valid addresses
    EXPECT_NO_THROW(installListenAddresses(valid_, store_, dnss_));
    checkAddresses(valid_, "Valid addresses");
    // TODO Maybe some test to actually connect to them
    // Try setting it back to nothing
    EXPECT_NO_THROW(installListenAddresses(AddressList(), store_, dnss_));
    checkAddresses(AddressList(), "No addresses");
    // Try switching back again
    EXPECT_NO_THROW(installListenAddresses(valid_, store_, dnss_));
    checkAddresses(valid_, "Valid addresses");
}

// Try if rollback works
TEST_F(InstallListenAddresses, rollback) {
    // Set some addresses
    EXPECT_NO_THROW(installListenAddresses(valid_, store_, dnss_));
    checkAddresses(valid_, "Before rollback");
    // This should not bind them, but should leave the original addresses
    EXPECT_THROW(installListenAddresses(invalid_, store_, dnss_), IOError);
    checkAddresses(valid_, "After rollback");
}

}
