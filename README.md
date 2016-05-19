barrel_erocksdb
===============

[![Build Status](https://travis-ci.org/barrel-db/barrel_rocksdb.svg?branch=master)](http://travis-ci.org/barrel-db/barrel_rocksdb)

Erlang bindings to [RocksDB](https://github.com/facebook/rocksdb) datastore.

This binding is a fork of [erocksdb](https://github.com/leo-project/erocksdb)
customized for the [Barrel DB](https://barrel-db.org) project.


Main differences are the following:

- Erlang 18 and sup only
- Use dirty-nifs
- Complete refactoring of the source code under the `erocksdb` namespace
- add single put and single delete operations
- add functions to handle the transactions logs
- latest stable version of rocksdb

## Build Information

$ rebar3 eunit

## Status

Passed all the tests derived from [eleveldb](https://github.com/basho/eleveldb)

## License

barrel_rocksdb's license is [Apache License Version 2.0](http://www.apache.org/licenses/LICENSE-2.0.html)

## Codebase

This code is based on [basho’s eleveldb](https://github.com/basho/eleveldb).
