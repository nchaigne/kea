// Copyright (C) 2013  Internet Systems Consortium, Inc. ("ISC")
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

#ifndef D2_LOG_H
#define D2_LOG_H

#include <log/logger_support.h>
#include <log/macros.h>
#include <d2/d2_messages.h>

namespace isc {
namespace d2 {

/// @brief Defines the executable name, ultimately this is the BIND10 module 
/// name.
extern const char* const D2_MODULE_NAME;

/// Define the logger for the "d2" module part of b10-d2.  We could define
/// a logger in each file, but we would want to define a common name to avoid
/// spelling mistakes, so it is just one small step from there to define a
/// module-common logger.
extern isc::log::Logger d2_logger;


} // namespace d2
} // namespace isc

#endif // D2_LOG_H
