Pathblazer is an application library to help with paths and configuration.  It can:

- Handle OS and file system differences with path format and case sensitivity
- Allow interaction with many data sources including file, web, SQL, in-memory
  Ruby code, through a unified path interface
- Layer data sources on top of each other, mapping them where they don't fit,
  to create unified interfaces
- Expose data for read and write via web and ssl
- Add authorization, caching, and other features to anything.
- Make it easy to attach user path searches like * and ** to arbitrary data sources

A store represents a system that can use paths to get or set a tree of
values.  (Not all stores can set values.)

Stores can be both base stores, or filters on top of a store.  Filters
exist on top of real stores, and can filter, transform, or remap values.

Base stores include:
- file_store - exposes file operations as get, set, post, delete, lock and
  subscribe.
- memory_store - exposes operations on hash, array and other values.
- http_store('http[s]://user@blah.com:881/path') - exposes the http server
  GET, PUT, POST and DELETE methods as get/set/create/delete, and adds a
  "request" method of its own that can pass any request.  Does not support
  subscribe.
- ftp_store('ftp://user@blah.com:881/path') - exposes the ftp server as a
  value store.
- scp_store('scp://user@blah.com:8080/path', exposes a server's files using scp
- etcd_store('etcd:[url]') - url to an etcd server.  If no URL is given, it
  points at https://discovery.etcd.io.
- aws_store - do we need specific ones for specific services or can we expose
  the whole tree in one shebang and let people figure it out from there?

System capabilities exposition:
- process(pid | system_command) - store that exposes information about a
  process.  Buffering of stdout/stderr can be specified.  Tree looks like:
  pid, stdout, stderr
- clients - store that exposes a network connection.  Tree looks like
  <host>/{tcp,udp}/<port>/{actual_port,status,stream}
- servers - store that exposes a server connection.  Tree looks like
  <host>/{tcp,udp}/<port>/status
                          actual_hosts/<host>/<port>
                          clients/{port,}

Mappers and generic filters:
- pathmap([path,store]*) - allows you to combine multiple stores into one.
  It consists of a list of [path, resolver] pairs.  When a path matches one
  or more paths, the corresponding method on the resolver is called with
  the remaining path and a special :prematch option that contains the
  matched path (which may have results in it).
- transform(store,{:new_path => transform,:action => function()->(path,value))
  easy way to write an inline transforming store that will call the given
  action on the underlying store, and then pass the value to your transform
  function.

Standard transforms:
- json
- yaml
- ruby_instance_eval(class)
- xml?
- md5 - only md5s on the way in.

Capability addition filters:
- local_subscriber(store) - adds the subscribe() option to stores that do
  not have it, notifying when set/create/delete methods are successful.
- hash_content_id(store) - adds :content_id and :if_modified_since support
  to an store that does not have it, by hashing the content.  May
  optionally be given a store to save expensive hashes.  Does not create
  content ids for things that already have it.
- local_modified(store) - adds :modified and :if_modified_since support to a
  store that does not have it. May optionally be given a store to save
  creation and modification times.
- limit(store, n) - a limit on the number of immediate subdirectories a tree
  can have.

New feature addition filters:
- cache(store, cache_store) - caches values retrieved from the given store
  in the cache_store.  Use a memory store with a tight expiration policy for
  a cheap time-limited cache.  Use a persistent store for a persistent cache.
- require_authorization(store, auth_store) - each time a request is made,
  checks if the requesting_user is able to perform the given action.
- authorization_inheritance(store) - put on front of a real storage device,
  it handles construction of default acls for objects based on inheritance.
- expose_rest - implements get/list/etc. in real REST parlance--assumes the
  responses from the server follow the REST standard.
- encrypted(store, private_key, public_key) - encrypts data in the given store
  with the given private key, for the given public key.
- lock(store=nil, type=:hierarchical, read_actions=[:get,:list]) - creates a
  mutex locking a store. Operations in the read group can proceed
  simultaneously but will block if any other actions are occurring.
  lock(path, [ :get, :list ]) will get an object which can be used to perform
  those operations, and which has an unlock() method. lock(path, :data
  => true) will return data about the lock itself. If type is :hierarchical,
  updates to x/y block reads and writes to x/y/* but nothing else. If the
  type is :single, any update to anything in the store will block reads and
  updates to anything else in the store.
- ephemeral(store) - files created under the store only exist as long as the
  creator exists.  The creator will receive a subscription / resolver to the
  top of their store and when that resolver reference disappears or network
  connection breaks, the data goes away.
- execution_pool(store) - a pool of process creators.  Creating a value under
  will trigger a process to start.  Pools can be limited with metadata.

Users of the store include:
- rack_router(store): expose a store as a Rack router that can be plugged in
  to a web server.
- basic_auth(store, basic_auth_password_store) - adds basic web authentication
  to passwords.
- action_history(store, history_store) - takes any actions sent to the store
  and records them, along with response times, requesting user and options,
  to the history_store.
- update_history(store, history_store) - subscribes to the store (may be
  given paths to subscribe to) and logs any updates into history_store.

TODO consider how to handle unending streams of values, such as logs and monitoring.
     Some files are that way, too: witness stdout and stderr.  Maybe add a
     buffering helper.

Locks, subscriptions and wait-for actions are supported.

This can be used as bulk copy, mirroring, and diff on a highly efficient
scale.

NOTE: the bulk copy and get can be streamlined quite a bit by strategically
sending if-modified-since and the toppest-level paths we can, and drilling
down as she goes.  The protocol could specify that the target will
tell the source about if-modified-since directories as soon as possible,
and the source could stop asking for such data.
