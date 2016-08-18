barrel_erocksdb
===============

**This is the fork of https://github.com/barrel-db/barrel_rocksdb with DBWithTTL instead of simple Db and with static
linking, including static `libstdc++` but not including `libc`. Some tests are failing, don't use anything
`updates_iterator`, `binary_update` and transactions. Rest things seem working**

**Contains patch for rocksdb db_ttl_impl.**


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

## License

barrel_rocksdb's license is [Apache License Version 2.0](http://www.apache.org/licenses/LICENSE-2.0.html)
