barrel_erocksdb
===============

**This is a fork of https://github.com/barrel-db/barrel_rocksdb with DbWithTTL instead of simple Db and with static
linking, including static `libstdc++` but not including `libc`. Some tests are failing, don't use anything like
`updates_iterator`, `binary_update` and transactions. The rest things seem working.**

**Contains patch for rocksdb db_ttl_impl.**

**Don't forget to change path to `libstdc++.a` in rebar.config. Also you may or may not have to compile your
own custom build of gcc
with `./configure CXXFLAGS=-fPIC CFLAGS=-fPIC --enable-languages=c,c++ --disable-gnu-unique-object`**


Erlang bindings to [RocksDB](https://github.com/facebook/rocksdb) datastore.

This binding is a fork of [erocksdb](https://github.com/leo-project/erocksdb)
customized for the [Barrel DB](https://barrel-db.org) project.


Main differences are the following:

- Erlang 19 and sup only
- Use dirty-nifs
- Complete refactoring of the source code under the `erocksdb` namespace
- add single put and single delete operations
- add functions to handle the transactions logs

## Build Information

    $ rebar3 eunit

## License

barrel_rocksdb's license is [Apache License Version 2.0](http://www.apache.org/licenses/LICENSE-2.0.html)
