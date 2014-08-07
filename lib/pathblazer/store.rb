require 'pathblazer/path_map'

module Pathblazer
  #
  # A Store is a PathMap that maps paths to StoreResults, and sports a few other
  # features:
  #
  # - metadata
  # - locking
  # - subscriptions
  # - efficient diffing and bulk copy
  #
  # Store implementors need not concern themselves with any of these features
  # unless they are supported: the core Store implementation implements everything
  # in terms of the underlying PathMap, so implementing each, set, delete and
  # range is the natural minimum you have to do.
  #
  class Store < PathMap
    #
    # Copy entries matching source.range into source.
    #
    # Values will only be copied if the source is definitely more up to date
    # than the destination.
    #
    # The source and destination's locks will be checked to see if they are
    # still in effect; if they are not, a BrokenLockError will occur.
    #
    # If the source has content-id or modified dates in it, these will be checked
    # against existing data before wasting time copying or retrieving that
    # information.
    #
    # Results are in the format:
    #
    # {
    #   :error => error
    #   :value => ...
    #   :stream => ...
    #   :content_id => ...
    #   :last_modified => ...
    #   :provenance => ...
    #   :action_trace => ...
    #   :store_metadata => ...
    # }
    #
    # Returns:
    #   locks, subscriptions and errors
    #
    # Options:
    # - data: data to copy: one ore more of :value, :stream, :content_id, :last_modified,
    #   :provenance, :action_trace, and :store_metadata.  By default, it gets :value,
    #   :content_id and :last_modified.
    # - lock: [ 'read/{metadata,subscribe,lock}', 'write/{update,create,lock,delete}' ] - take lock(s) on dest.range
    # - subscribe: true - subscribe to dest.range
    # - mirror: replace all entries in dest regardless of up-to-date-ness.
    # - non_blocking: if you will have to wait on a lock, don't bother.
    #
    # Exceptions returned in the response:
    # - DataLockedError - the data cannot be locked for write at this time.
    # - DataAlreadyExistsError - a path created already exists.
    # - ParentDoesNotExistError - a parent of a path was not found and .
    # - standard exceptions - see class definition
    #
    def copy(store, options = {})
      raise ActionNotSupportedError.new(:copy_to, self)
    end

    #
    # Moves, renames and deletes paths.
    #
    # If the path_store contains just paths, those will be used.  If the path_store
    # contains modified and content-id data, paths will only be moved or deleted
    # if they match the modified / content-id data.
    #
    # Options:
    # - :non_blocking: if you will have to wait on a lock, don't bother.
    #
    # Exceptions:
    # - DataLockedError        - the data cannot be locked for write at this time.
    # - DataAlreadyExistsError - the target path already exists.
    # - DataDoesNotExistError  - the target path does not exist.
    def move(path_store, options = {})
      raise ActionNotSupportedError.new(:move, self)
    end
  end
end
