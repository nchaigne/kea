/* Copyright (C) 2015-2016 Internet Systems Consortium, Inc. ("ISC")

   This Source Code Form is subject to the terms of the Mozilla Public
   License, v. 2.0. If a copy of the MPL was not distributed with this
   file, You can obtain one at http://mozilla.org/MPL/2.0/. */

%skeleton "lalr1.cc" /* -*- C++ -*- */
%require "3.0.0"
%defines
%define parser_class_name {Dhcp6Parser}
%define api.prefix {parser6_}
%define api.token.constructor
%define api.value.type variant
%define api.namespace {isc::dhcp}
%define parse.assert
%code requires
{
#include <string>
#include <cc/data.h>
#include <dhcp/option.h>
#include <boost/lexical_cast.hpp>
#include <dhcp6/parser_context_decl.h>

using namespace isc::dhcp;
using namespace isc::data;
using namespace std;
}
// The parsing context.
%param { isc::dhcp::Parser6Context& ctx }
%locations
%define parse.trace
%define parse.error verbose
%code
{
#include <dhcp6/parser_context.h>

}


%define api.token.prefix {TOKEN_}
// Tokens in an order which makes sense and related to the intented use.
%token
  END  0  "end of file"
  COMMA ","
  COLON ":"
  LSQUARE_BRACKET "["
  RSQUARE_BRACKET "]"
  LCURLY_BRACKET "{"
  RCURLY_BRACKET "}"
  NULL_TYPE "null"

  DHCP6 "Dhcp6"
  INTERFACES_CONFIG "interfaces-config"
  INTERFACES "interfaces"

  LEASE_DATABASE "lease-database"
  HOSTS_DATABASE "hosts-database"
  TYPE "type"
  USER "user"
  PASSWORD "password"
  HOST "host"
  PERSIST "persist"
  LFC_INTERVAL "lfc-interval"

  PREFERRED_LIFETIME "preferred-lifetime"
  VALID_LIFETIME "valid-lifetime"
  RENEW_TIMER "renew-timer"
  REBIND_TIMER "rebind-timer"
  SUBNET6 "subnet6"
  OPTION_DATA "option-data"
  NAME "name"
  DATA "data"
  CODE "code"
  SPACE "space"
  CSV_FORMAT "csv-format"

  POOLS "pools"
  POOL "pool"
  PD_POOLS "pd-pools"
  PREFIX "prefix"
  PREFIX_LEN "prefix-len"
  DELEGATED_LEN "delegated-len"

  SUBNET "subnet"
  INTERFACE "interface"
  ID "id"

  MAC_SOURCES "mac-sources"
  RELAY_SUPPLIED_OPTIONS "relay-supplied-options"
  HOST_RESERVATION_IDENTIFIERS "host-reservation-identifiers"

  CLIENT_CLASSES "client-classes"
  TEST "test"
  CLIENT_CLASS "client-class"

  RESERVATIONS "reservations"
  IP_ADDRESSES "ip-addresses"
  PREFIXES "prefixes"
  DUID "duid"
  HW_ADDRESS "hw-address"
  HOSTNAME "hostname"

  HOOKS_LIBRARIES "hooks-libraries"
  LIBRARY "library"

  EXPIRED_LEASES_PROCESSING "expired-leases-processing"

  SERVER_ID "server-id"
  IDENTIFIER "identifier"
  HTYPE "htype"
  TIME "time"
  ENTERPRISE_ID "enterprise-id"

  DHCP4O6_PORT "dhcp4o6-port"

  LOGGING "Logging"
  LOGGERS "loggers"
  OUTPUT_OPTIONS "output_options"
  OUTPUT "output"
  DEBUGLEVEL "debuglevel"
  SEVERITY "severity"

  DHCP_DDNS "dhcp-ddns"
  ENABLE_UPDATES "enable-updates"
  QUALIFYING_SUFFIX "qualifying-suffix"

 // Not real tokens, just a way to signal what the parser is expected to
 // parse.
  TOPLEVEL_GENERIC_JSON
  TOPLEVEL_DHCP6
;

%token <std::string> STRING "constant string"
%token <int64_t> INTEGER "integer"
%token <double> FLOAT "floating point"
%token <bool> BOOLEAN "boolean"

%type <ElementPtr> value

%printer { yyoutput << $$; } <*>;

%%

// The whole grammar starts with a map, because the config file
// constists of Dhcp, Logger and DhcpDdns entries in one big { }.
// %start map - this will parse everything as generic JSON
// %start dhcp6_map - this will parse everything with Dhcp6 syntax checking
%start start;

start: TOPLEVEL_GENERIC_JSON { ctx.ctx_ = ctx.NO_KEYWORD; } map2
     | TOPLEVEL_DHCP6 { ctx.ctx_ = ctx.CONFIG; } syntax_map
     ;

// ---- generic JSON parser ---------------------------------

// Note that ctx_ is NO_KEYWORD here

// Values rule
value: INTEGER { $$ = ElementPtr(new IntElement($1)); }
     | FLOAT { $$ = ElementPtr(new DoubleElement($1)); }
     | BOOLEAN { $$ = ElementPtr(new BoolElement($1)); }
     | STRING { $$ = ElementPtr(new StringElement($1)); }
     | NULL_TYPE { $$ = ElementPtr(new NullElement()); }
     | map2 { $$ = ctx.stack_.back(); ctx.stack_.pop_back(); }
     | list_generic { $$ = ctx.stack_.back(); ctx.stack_.pop_back(); }
     ;

map2: LCURLY_BRACKET {
    // This code is executed when we're about to start parsing
    // the content of the map
    ElementPtr m(new MapElement());
    ctx.stack_.push_back(m);
} map_content RCURLY_BRACKET {
    // map parsing completed. If we ever want to do any wrap up
    // (maybe some sanity checking), this would be the best place
    // for it.
};

// Assignments rule
map_content: %empty // empty map
           | not_empty_map
           ;

not_empty_map: STRING COLON value {
                  // map containing a single entry
                  ctx.stack_.back()->set($1, $3);
                  }
             | not_empty_map COMMA STRING COLON value {
                  // map consisting of a shorter map followed by
                  // comma and string:value
                  ctx.stack_.back()->set($3, $5);
                  }
             ;

list_generic: LSQUARE_BRACKET {
    ElementPtr l(new ListElement());
    ctx.stack_.push_back(l);
} list_content RSQUARE_BRACKET {
    // list parsing complete. Put any sanity checking here
};

// This one is used in syntax parser.
list2: LSQUARE_BRACKET {
    // List parsing about to start
} list_content RSQUARE_BRACKET {
    // list parsing complete. Put any sanity checking here
    //ctx.stack_.pop_back();
};

list_content: %empty // Empty list
            | not_empty_list
            ;

not_empty_list: value {
                  // List consisting of a single element.
                  ctx.stack_.back()->add($1);
                  }
              | not_empty_list COMMA value {
                  // List ending with , and a value.
                  ctx.stack_.back()->add($3);
                  }
              ;

// ---- generic JSON parser ends here ----------------------------------

// ---- syntax checking parser starts here -----------------------------

// This defines the top-level { } that holds Dhcp6, Dhcp4, DhcpDdns or Logging
// objects.
// ctx_ = CONFIG
syntax_map: LCURLY_BRACKET {
    // This code is executed when we're about to start parsing
    // the content of the map
    ElementPtr m(new MapElement());
    ctx.stack_.push_back(m);
} global_objects RCURLY_BRACKET {
    // map parsing completed. If we ever want to do any wrap up
    // (maybe some sanity checking), this would be the best place
    // for it.
};

// This represents top-level entries: Dhcp6, Dhcp4, DhcpDdns, Logging
global_objects: global_object
              | global_objects COMMA global_object
              ;

// This represents a single top level entry, e.g. Dhcp6 or DhcpDdns.
global_object: dhcp6_object
             | logging_object
             ;

dhcp6_object: DHCP6 {
    // This code is executed when we're about to start parsing
    // the content of the map
    ElementPtr m(new MapElement());
    ctx.stack_.back()->set("Dhcp6", m);
    ctx.stack_.push_back(m);
    ctx.enter(ctx.DHCP6);
} COLON LCURLY_BRACKET global_params RCURLY_BRACKET {
    // map parsing completed. If we ever want to do any wrap up
    // (maybe some sanity checking), this would be the best place
    // for it.
    ctx.stack_.pop_back();
    ctx.leave();
};

global_params: global_param
             | global_params COMMA global_param
             ;

// These are the parameters that are allowed in the top-level for
// Dhcp6.
global_param: preferred_lifetime
            | valid_lifetime
            | renew_timer
            | rebind_timer
            | subnet6_list
            | interfaces_config
            | lease_database
            | hosts_database
            | mac_sources
            | relay_supplied_options
            | host_reservation_identifiers
            | client_classes
            | option_data_list
            | hooks_libraries
            | expired_leases_processing
            | server_id
            | dhcp4o6_port
            | dhcp_ddns
            ;

preferred_lifetime: PREFERRED_LIFETIME COLON INTEGER {
    ElementPtr prf(new IntElement($3));
    ctx.stack_.back()->set("preferred-lifetime", prf);
};

valid_lifetime: VALID_LIFETIME COLON INTEGER {
    ElementPtr prf(new IntElement($3));
    ctx.stack_.back()->set("valid-lifetime", prf);
};

renew_timer: RENEW_TIMER COLON INTEGER {
    ElementPtr prf(new IntElement($3));
    ctx.stack_.back()->set("renew-timer", prf);
};

rebind_timer: REBIND_TIMER COLON INTEGER {
    ElementPtr prf(new IntElement($3));
    ctx.stack_.back()->set("rebind-timer", prf);
};

interfaces_config: INTERFACES_CONFIG {
    ElementPtr i(new MapElement());
    ctx.stack_.back()->set("interfaces-config", i);
    ctx.stack_.push_back(i);
    ctx.enter(ctx.INTERFACES_CONFIG);
} COLON LCURLY_BRACKET interface_config_map RCURLY_BRACKET {
    ctx.stack_.pop_back();
    ctx.leave();
};

interface_config_map: INTERFACES {
    ElementPtr l(new ListElement());
    ctx.stack_.back()->set("interfaces", l);
    ctx.stack_.push_back(l);
    ctx.enter(ctx.NO_KEYWORD);
} COLON list2 {
    ctx.stack_.pop_back();
    ctx.leave();
};

lease_database: LEASE_DATABASE {
    ElementPtr i(new MapElement());
    ctx.stack_.back()->set("lease-database", i);
    ctx.stack_.push_back(i);
    ctx.enter(ctx.DATABASE);
} COLON LCURLY_BRACKET database_map_params RCURLY_BRACKET {
    ctx.stack_.pop_back();
    ctx.leave();
};

hosts_database: HOSTS_DATABASE {
    ElementPtr i(new MapElement());
    ctx.stack_.back()->set("hosts-database", i);
    ctx.stack_.push_back(i);
    ctx.enter(ctx.DATABASE);
} COLON LCURLY_BRACKET database_map_params RCURLY_BRACKET {
    ctx.stack_.pop_back();
    ctx.leave();
};

database_map_params: database_map_param
                   | database_map_params COMMA database_map_param
                   ;

database_map_param: type
                  | user
                  | password
                  | host
                  | name
                  | persist
                  | lfc_interval;
;

type: TYPE {
    ctx.enter(ctx.NO_KEYWORD);
} COLON STRING {
    ElementPtr prf(new StringElement($4));
    ctx.stack_.back()->set("type", prf);
    ctx.leave();
};

user: USER {
    ctx.enter(ctx.NO_KEYWORD);
} COLON STRING {
    ElementPtr user(new StringElement($4));
    ctx.stack_.back()->set("user", user);
    ctx.leave();
};

password: PASSWORD {
    ctx.enter(ctx.NO_KEYWORD);
} COLON STRING {
    ElementPtr pwd(new StringElement($4));
    ctx.stack_.back()->set("password", pwd);
    ctx.leave();
};

host: HOST {
    ctx.enter(ctx.NO_KEYWORD);
} COLON STRING {
    ElementPtr h(new StringElement($4));
    ctx.stack_.back()->set("host", h);
    ctx.leave();
};

name: NAME {
    ctx.enter(ctx.NO_KEYWORD);
} COLON STRING {
    ElementPtr name(new StringElement($4));
    ctx.stack_.back()->set("name", name);
    ctx.leave();
};

persist: PERSIST COLON BOOLEAN {
    ElementPtr n(new BoolElement($3));
    ctx.stack_.back()->set("persist", n);
};

lfc_interval: LFC_INTERVAL COLON INTEGER {
    ElementPtr n(new IntElement($3));
    ctx.stack_.back()->set("lfc-interval", n);
};

mac_sources: MAC_SOURCES {
    ElementPtr l(new ListElement());
    ctx.stack_.back()->set("mac-sources", l);
    ctx.stack_.push_back(l);
    ctx.enter(ctx.MAC_SOURCES);
} COLON LSQUARE_BRACKET mac_sources_list RSQUARE_BRACKET {
    ctx.stack_.pop_back();
    ctx.leave();
};

mac_sources_list: mac_sources_value
                | mac_sources_list COMMA mac_sources_value
;

mac_sources_value: duid_id
                 | string_id
                 ;

duid_id : DUID {
    ElementPtr duid(new StringElement("duid"));
    ctx.stack_.back()->add(duid);
};

string_id : STRING {
    ElementPtr duid(new StringElement($1));
    ctx.stack_.back()->add(duid);
};

host_reservation_identifiers: HOST_RESERVATION_IDENTIFIERS {
    ElementPtr l(new ListElement());
    ctx.stack_.back()->set("host-reservation-identifiers", l);
    ctx.stack_.push_back(l);
    ctx.enter(ctx.HOST_RESERVATION_IDENTIFIERS);    
} COLON LSQUARE_BRACKET host_reservation_identifiers_list RSQUARE_BRACKET {
    ctx.stack_.pop_back();
    ctx.leave();
};

host_reservation_identifiers_list: host_reservation_identifier
    | host_reservation_identifiers_list COMMA host_reservation_identifier
    ;

host_reservation_identifier: duid_id
                           | hw_address_id
                           ;

hw_address_id : HW_ADDRESS {
    ElementPtr hwaddr(new StringElement("hw-address"));
    ctx.stack_.back()->add(hwaddr);
};

relay_supplied_options: RELAY_SUPPLIED_OPTIONS {
    ElementPtr l(new ListElement());
    ctx.stack_.back()->set("relay-supplied-options", l);
    ctx.stack_.push_back(l);
    ctx.enter(ctx.NO_KEYWORD);
} COLON list2 {
    ctx.stack_.pop_back();
    ctx.leave();
};

hooks_libraries: HOOKS_LIBRARIES {
    ElementPtr l(new ListElement());
    ctx.stack_.back()->set("hooks-libraries", l);
    ctx.stack_.push_back(l);
    ctx.enter(ctx.HOOKS_LIBRARIES);
} COLON LSQUARE_BRACKET hooks_libraries_list RSQUARE_BRACKET {
    ctx.stack_.pop_back();
    ctx.leave();
};

hooks_libraries_list: %empty
                    | not_empty_hooks_libraries_list
                    ;

not_empty_hooks_libraries_list: hooks_library
    | not_empty_hooks_libraries_list COMMA hooks_library
    ;

hooks_library: LCURLY_BRACKET {
    ElementPtr m(new MapElement());
    ctx.stack_.back()->add(m);
    ctx.stack_.push_back(m);
} hooks_params RCURLY_BRACKET {
    ctx.stack_.pop_back();
};

hooks_params: hooks_param
            | hooks_params hooks_param
            ;

hooks_param: LIBRARY {
    ctx.enter(ctx.NO_KEYWORD);
} COLON STRING {
    ElementPtr lib(new StringElement($4));
    ctx.stack_.back()->set("library", lib);
    ctx.leave(); 
};

// --- expired-leases-processing ------------------------
expired_leases_processing: EXPIRED_LEASES_PROCESSING {
    ElementPtr m(new MapElement());
    ctx.stack_.back()->set("expired-leases-processing", m);
    ctx.stack_.push_back(m);
    ctx.enter(ctx.NO_KEYWORD);
} COLON LCURLY_BRACKET expired_leases_params RCURLY_BRACKET {
    ctx.stack_.pop_back();
    ctx.leave();
};

expired_leases_params: expired_leases_param
                     | expired_leases_params COMMA expired_leases_param
                     ;

// This is a bit of a simplification. But it can also serve as an example.
// Instead of explicitly listing all allowed expired leases parameters, we
// simply say that all of them as integers.
expired_leases_param: STRING COLON INTEGER {
    ElementPtr value(new IntElement($3));
    ctx.stack_.back()->set($1, value);
}

// --- subnet6 ------------------------------------------
// This defines subnet6 as a list of maps.
// "subnet6": [ ... ]
subnet6_list: SUBNET6 {
    ElementPtr l(new ListElement());
    ctx.stack_.back()->set("subnet6", l);
    ctx.stack_.push_back(l);
    ctx.enter(ctx.SUBNET6);
} COLON LSQUARE_BRACKET subnet6_list_content RSQUARE_BRACKET {
    ctx.stack_.pop_back();
    ctx.leave();
};

// This defines the ... in "subnet6": [ ... ]
// It can either be empty (no subnets defined), have one subnet
// or have multiple subnets separate by comma.
subnet6_list_content: %empty
                    | not_empty_subnet6_list
                    ;

not_empty_subnet6_list: subnet6
                      | not_empty_subnet6_list COMMA subnet6
                      ;

// --- Subnet definitions -------------------------------

// This defines a single subnet, i.e. a single map with
// subnet6 array.
subnet6: LCURLY_BRACKET {
    ElementPtr m(new MapElement());
    ctx.stack_.back()->add(m);
    ctx.stack_.push_back(m);
} subnet6_params RCURLY_BRACKET {
    // Once we reached this place, the subnet parsing is now complete.
    // If we want to, we can implement default values here.
    // In particular we can do things like this:
    // if (!ctx.stack_.back()->get("interface")) {
    //     ctx.stack_.back()->set("interface", StringElement("loopback"));
    // }
    //
    // We can also stack up one level (Dhcp6) and copy over whatever
    // global parameters we want to:
    // if (!ctx.stack_.back()->get("renew-timer")) {
    //     ElementPtr renew = ctx_stack_[...].get("renew-timer");
    //     if (renew) {
    //         ctx.stack_.back()->set("renew-timer", renew);
    //     }
    // }
    ctx.stack_.pop_back();
};

// This defines that subnet can have one or more parameters.
subnet6_params: subnet6_param
              | subnet6_params COMMA subnet6_param
              ;

// This defines a list of allowed parameters for each subnet.
subnet6_param: option_data_list
             | pools_list
             | pd_pools_list
             | subnet
             | interface
             | id
             | client_class
             | reservations
             ;

subnet: SUBNET {
    ctx.enter(ctx.NO_KEYWORD);
} COLON STRING {
    ElementPtr subnet(new StringElement($4));
    ctx.stack_.back()->set("subnet", subnet);
    ctx.leave();
};

interface: INTERFACE {
    ctx.enter(ctx.NO_KEYWORD);
} COLON STRING {
    ElementPtr iface(new StringElement($4));
    ctx.stack_.back()->set("interface", iface);
    ctx.leave();
};

client_class: CLIENT_CLASS {
    ctx.enter(ctx.CLIENT_CLASS);
} COLON STRING {
    ElementPtr cls(new StringElement($4));
    ctx.stack_.back()->set("client-class", cls);
    ctx.leave();
};

id: ID COLON INTEGER {
    ElementPtr id(new IntElement($3));
    ctx.stack_.back()->set("id", id);
};

// ---- option-data --------------------------

// This defines the "option-data": [ ... ] entry that may appear
// in several places, but most notably in subnet6 entries.
option_data_list: OPTION_DATA {
    ElementPtr l(new ListElement());
    ctx.stack_.back()->set("option-data", l);
    ctx.stack_.push_back(l);
    ctx.enter(ctx.OPTION_DATA);
} COLON LSQUARE_BRACKET option_data_list_content RSQUARE_BRACKET {
    ctx.stack_.pop_back();
    ctx.leave();
};

// This defines the content of option-data. It may be empty,
// have one entry or multiple entries separated by comma.
option_data_list_content: %empty
                        | not_empty_option_data_list
                        ;

not_empty_option_data_list: option_data_entry
                          | not_empty_option_data_list COMMA option_data_entry
                          ;

// This defines th content of a single entry { ... } within
// option-data list.
option_data_entry: LCURLY_BRACKET {
    ElementPtr m(new MapElement());
    ctx.stack_.back()->add(m);
    ctx.stack_.push_back(m);
} option_data_params RCURLY_BRACKET {
    ctx.stack_.pop_back();
};

// This defines parameters specified inside the map that itself
// is an entry in option-data list.
option_data_params: %empty
                  | not_empty_option_data_params
                  ;

not_empty_option_data_params: option_data_param
    | not_empty_option_data_params COMMA option_data_param
    ;

option_data_param: option_data_name
                 | option_data_data
                 | option_data_code
                 | option_data_space
                 | option_data_csv_format
                 ;


option_data_name: name;

option_data_data: DATA {
    ctx.enter(ctx.NO_KEYWORD);
} COLON STRING {
    ElementPtr data(new StringElement($4));
    ctx.stack_.back()->set("data", data);
    ctx.leave();
};

option_data_code: CODE COLON INTEGER {
    ElementPtr code(new IntElement($3));
    ctx.stack_.back()->set("code", code);
};

option_data_space: SPACE {
    ctx.enter(ctx.NO_KEYWORD);
} COLON STRING {
    ElementPtr space(new StringElement($4));
    ctx.stack_.back()->set("space", space);
    ctx.leave();
};

option_data_csv_format: CSV_FORMAT COLON BOOLEAN {
    ElementPtr space(new BoolElement($3));
    ctx.stack_.back()->set("csv-format", space);
};

// ---- pools ------------------------------------

// This defines the "pools": [ ... ] entry that may appear in subnet6.
pools_list: POOLS {
    ElementPtr l(new ListElement());
    ctx.stack_.back()->set("pools", l);
    ctx.stack_.push_back(l);
    ctx.enter(ctx.POOLS);
} COLON LSQUARE_BRACKET pools_list_content RSQUARE_BRACKET {
    ctx.stack_.pop_back();
    ctx.leave();
};

// Pools may be empty, contain a single pool entry or multiple entries
// separate by commas.
pools_list_content: %empty
                  | not_empty_pools_list
                  ;

not_empty_pools_list: pool_list_entry
                    | not_empty_pools_list COMMA pool_list_entry
                    ;

pool_list_entry: LCURLY_BRACKET {
    ElementPtr m(new MapElement());
    ctx.stack_.back()->add(m);
    ctx.stack_.push_back(m);
} pool_params RCURLY_BRACKET {
    ctx.stack_.pop_back();
};

pool_params: pool_param
           | pool_params COMMA pool_param
           ;

pool_param: pool_entry
          | option_data_list
          ;

pool_entry: POOL {
    ctx.enter(ctx.NO_KEYWORD);
} COLON STRING {
    ElementPtr pool(new StringElement($4));
    ctx.stack_.back()->set("pool", pool);
    ctx.leave();
};

// --- end of pools definition -------------------------------

// --- pd-pools ----------------------------------------------
pd_pools_list: PD_POOLS {
    ElementPtr l(new ListElement());
    ctx.stack_.back()->set("pd-pools", l);
    ctx.stack_.push_back(l);
    ctx.enter(ctx.PD_POOLS);
} COLON LSQUARE_BRACKET pd_pools_list_content RSQUARE_BRACKET {
    ctx.stack_.pop_back();
    ctx.leave();
};

// Pools may be empty, contain a single pool entry or multiple entries
// separate by commas.
pd_pools_list_content: %empty
                     | not_empty_pd_pools_list
                     ;

not_empty_pd_pools_list: pd_pool_entry
                       | not_empty_pd_pools_list COMMA pd_pool_entry
                       ;

pd_pool_entry: LCURLY_BRACKET {
    ElementPtr m(new MapElement());
    ctx.stack_.back()->add(m);
    ctx.stack_.push_back(m);
} pd_pool_params RCURLY_BRACKET {
    ctx.stack_.pop_back();
};

pd_pool_params: pd_pool_param
              | pd_pool_params COMMA pd_pool_param
              ;

pd_pool_param: pd_prefix
             | pd_prefix_len
             | pd_delegated_len
             | option_data_list
             ;

pd_prefix: PREFIX {
    ctx.enter(ctx.NO_KEYWORD);
} COLON STRING {
    ElementPtr prf(new StringElement($4));
    ctx.stack_.back()->set("prefix", prf);
    ctx.leave();
}

pd_prefix_len: PREFIX_LEN COLON INTEGER {
    ElementPtr prf(new IntElement($3));
    ctx.stack_.back()->set("prefix-len", prf);
}

pd_delegated_len: DELEGATED_LEN COLON INTEGER {
    ElementPtr deleg(new IntElement($3));
    ctx.stack_.back()->set("delegated-len", deleg);
}

// --- end of pd-pools ---------------------------------------

// --- reservations ------------------------------------------
reservations: RESERVATIONS {
    ElementPtr l(new ListElement());
    ctx.stack_.back()->set("reservations", l);
    ctx.stack_.push_back(l);
    ctx.enter(ctx.RESERVATIONS);
} COLON LSQUARE_BRACKET reservations_list RSQUARE_BRACKET {
    ctx.stack_.pop_back();
    ctx.leave();
};

reservations_list: %empty
                 | not_empty_reservations_list
                 ;

not_empty_reservations_list: reservation
                           | not_empty_reservations_list COMMA reservation
                           ;

reservation: LCURLY_BRACKET {
    ElementPtr m(new MapElement());
    ctx.stack_.back()->add(m);
    ctx.stack_.push_back(m);
} reservation_params RCURLY_BRACKET {
    ctx.stack_.pop_back();
};

reservation_params: %empty
                  | not_empty_reservation_params
                  ;

not_empty_reservation_params: reservation_param
    | not_empty_reservation_params COMMA reservation_param
    ;

// @todo probably need to add mac-address as well here
reservation_param: duid
                 | reservation_client_classes
                 | ip_addresses
                 | prefixes
                 | hw_address
                 | hostname
                 | option_data_list
                 ;

ip_addresses: IP_ADDRESSES {
    ElementPtr l(new ListElement());
    ctx.stack_.back()->set("ip-addresses", l);
    ctx.stack_.push_back(l);
    ctx.enter(ctx.NO_KEYWORD);
} COLON list2 {
    ctx.stack_.pop_back();
    ctx.leave();
};

prefixes: PREFIXES  {
    ElementPtr l(new ListElement());
    ctx.stack_.back()->set("prefixes", l);
    ctx.stack_.push_back(l);
    ctx.enter(ctx.NO_KEYWORD);
} COLON list2 {
    ctx.stack_.pop_back();
    ctx.leave();
};

duid: DUID {
    ctx.enter(ctx.NO_KEYWORD);
} COLON STRING {
    ElementPtr d(new StringElement($4));
    ctx.stack_.back()->set("duid", d);
    ctx.leave();
};

hw_address: HW_ADDRESS {
    ctx.enter(ctx.NO_KEYWORD);
} COLON STRING {
    ElementPtr hw(new StringElement($4));
    ctx.stack_.back()->set("hw-address", hw);
    ctx.leave();
};

hostname: HOSTNAME {
    ctx.enter(ctx.NO_KEYWORD);
} COLON STRING {
    ElementPtr host(new StringElement($4));
    ctx.stack_.back()->set("hostname", host);
    ctx.leave();
}

reservation_client_classes: CLIENT_CLASSES {
    ElementPtr c(new ListElement());
    ctx.stack_.back()->set("client-classes", c);
    ctx.stack_.push_back(c);
    ctx.enter(ctx.NO_KEYWORD);
} COLON list2 {
    ctx.stack_.pop_back();
    ctx.leave();
};

// --- end of reservations definitions -----------------------

// --- client classes ----------------------------------------
client_classes: CLIENT_CLASSES {
    ElementPtr l(new ListElement());
    ctx.stack_.back()->set("client-classes", l);
    ctx.stack_.push_back(l);
    ctx.enter(ctx.CLIENT_CLASSES);
} COLON LSQUARE_BRACKET client_classes_list RSQUARE_BRACKET {
    ctx.stack_.pop_back();
    ctx.leave();
};

client_classes_list: client_class
                   | client_classes_list COMMA client_class
                   ;

client_class: LCURLY_BRACKET {
    ElementPtr m(new MapElement());
    ctx.stack_.back()->add(m);
    ctx.stack_.push_back(m);
} client_class_params RCURLY_BRACKET {
    ctx.stack_.pop_back();
};

client_class_params: %empty
                   | not_empty_client_class_params
                   ;

not_empty_client_class_params: client_class_param
    | not_empty_client_class_params COMMA client_class_param
    ;

client_class_param: client_class_name
                  | client_class_test
                  | option_data_list
                  ;

client_class_name: name;

client_class_test: TEST {
    ctx.enter(ctx.NO_KEYWORD);
} COLON STRING {
    ElementPtr test(new StringElement($4));
    ctx.stack_.back()->set("test", test);
    ctx.leave();
}


// --- end of client classes ---------------------------------

// --- server-id ---------------------------------------------
server_id: SERVER_ID {
    ElementPtr m(new MapElement());
    ctx.stack_.back()->set("server-id", m);
    ctx.stack_.push_back(m);
    ctx.enter(ctx.SERVER_ID);
} COLON LCURLY_BRACKET server_id_params RCURLY_BRACKET {
    ctx.stack_.pop_back();
    ctx.leave();
};

server_id_params: server_id_param
                | server_id_params COMMA server_id_param
                ;

server_id_param: type
               | identifier
               | time
               | htype
               | enterprise_id
               | persist
               ;

htype: HTYPE COLON INTEGER {
    ElementPtr htype(new IntElement($3));
    ctx.stack_.back()->set("htype", htype);
};

identifier: IDENTIFIER {
    ctx.enter(ctx.NO_KEYWORD);
} COLON STRING {
    ElementPtr id(new StringElement($4));
    ctx.stack_.back()->set("identifier", id);
    ctx.leave();
};

time: TIME COLON INTEGER {
    ElementPtr time(new IntElement($3));
    ctx.stack_.back()->set("time", time);
};

enterprise_id: ENTERPRISE_ID COLON INTEGER {
    ElementPtr time(new IntElement($3));
    ctx.stack_.back()->set("enterprise-id", time);
};

// --- end of server-id --------------------------------------

dhcp4o6_port: DHCP4O6_PORT COLON INTEGER {
    ElementPtr time(new IntElement($3));
    ctx.stack_.back()->set("dhcp4o6-port", time);
};

// --- logging entry -----------------------------------------

// This defines the top level "Logging" object. It parses
// the following "Logging": { ... }. The ... is defined
// by logging_params
logging_object: LOGGING {
    ElementPtr m(new MapElement());
    ctx.stack_.back()->set("Logging", m);
    ctx.stack_.push_back(m);
    ctx.enter(ctx.LOGGING);
} COLON LCURLY_BRACKET logging_params RCURLY_BRACKET {
    ctx.stack_.pop_back();
    ctx.leave();
};

// This defines the list of allowed parameters that may appear
// in the top-level Logging object. It can either be a single
// parameter or several parameters separated by commas.
logging_params: logging_param
              | logging_params COMMA logging_param
              ;

// There's currently only one parameter defined, which is "loggers".
logging_param: loggers;

// "loggers", the only parameter currently defined in "Logging" object,
// is "Loggers": [ ... ].
loggers: LOGGERS {
    ElementPtr l(new ListElement());
    ctx.stack_.back()->set("loggers", l);
    ctx.stack_.push_back(l);
    ctx.enter(ctx.LOGGERS);
}  COLON LSQUARE_BRACKET loggers_entries RSQUARE_BRACKET {
    ctx.stack_.pop_back();
    ctx.leave();
};

// These are the parameters allowed in loggers: either one logger
// entry or multiple entries separate by commas.
loggers_entries: logger_entry
               | loggers_entries COMMA logger_entry
               ;

// This defines a single entry defined in loggers in Logging.
logger_entry: LCURLY_BRACKET {
    ElementPtr l(new MapElement());
    ctx.stack_.back()->add(l);
    ctx.stack_.push_back(l);
} logger_params RCURLY_BRACKET {
    ctx.stack_.pop_back();
};

logger_params: logger_param
             | logger_params COMMA logger_param
             ;

logger_param: name
            | output_options_list
            | debuglevel
            | severity
            ;

debuglevel: DEBUGLEVEL COLON INTEGER {
    ElementPtr dl(new IntElement($3));
    ctx.stack_.back()->set("debuglevel", dl);
};
severity: SEVERITY {
    ctx.enter(ctx.NO_KEYWORD);
} COLON STRING {
    ElementPtr sev(new StringElement($4));
    ctx.stack_.back()->set("severity", sev);
    ctx.leave();
};

output_options_list: OUTPUT_OPTIONS {
    ElementPtr l(new ListElement());
    ctx.stack_.back()->set("output_options", l);
    ctx.stack_.push_back(l);
    ctx.enter(ctx.OUTPUT_OPTIONS);
} COLON LSQUARE_BRACKET output_options_list_content RSQUARE_BRACKET {
    ctx.stack_.pop_back();
    ctx.leave();
};

output_options_list_content: output_entry
                           | output_options_list_content COMMA output_entry
                           ;

output_entry: LCURLY_BRACKET {
    ElementPtr m(new MapElement());
    ctx.stack_.back()->add(m);
    ctx.stack_.push_back(m);
} output_params RCURLY_BRACKET {
    ctx.stack_.pop_back();
};

output_params: output_param
             | output_params COMMA output_param
             ;

output_param: OUTPUT {
    ctx.enter(ctx.NO_KEYWORD);
} COLON STRING {
    ElementPtr sev(new StringElement($4));
    ctx.stack_.back()->set("output", sev);
    ctx.leave();
};

dhcp_ddns: DHCP_DDNS {
    ElementPtr m(new MapElement());
    ctx.stack_.back()->set("dhcp-ddns", m);
    ctx.stack_.push_back(m);
    ctx.enter(ctx.DHCP_DDNS);
} COLON LCURLY_BRACKET dhcp_ddns_params RCURLY_BRACKET {
    ctx.stack_.pop_back();
    ctx.leave();
};

dhcp_ddns_params: dhcp_ddns_param
                | dhcp_ddns_params COMMA dhcp_ddns_param
                ;

dhcp_ddns_param: enable_updates
               | qualifying_suffix
               ;

enable_updates: ENABLE_UPDATES COLON BOOLEAN {
    ElementPtr b(new BoolElement($3));
    ctx.stack_.back()->set("enable-updates", b);
};

qualifying_suffix: QUALIFYING_SUFFIX {
    ctx.enter(ctx.NO_KEYWORD);
} COLON STRING {
    ElementPtr qs(new StringElement($4));
    ctx.stack_.back()->set("qualifying-suffix", qs);
    ctx.leave();
};

%%

void
isc::dhcp::Dhcp6Parser::error(const location_type& loc,
                              const std::string& what)
{
    ctx.error(loc, what);
}
