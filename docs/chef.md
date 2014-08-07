# Chef config

## .rb file

A sample .rb file:

```ruby
chef_server 'https://api.opscode.com/organizations/blah' do
  user 'jkeiser'
end
```

How configuration is defined:

```ruby
class Chef::Context < Pathblazer::Context
  def initialize
    super
    initialize_config
  end

  attr_reader :defaults
  attr_reader :validator
  attr_reader :config_files

  def chef_api
    path.source(config.chef_server.url)
  end

  def initialize_config
    @defaults = path.store.memory
    @config_files = path.store.lazy_store do
      path.store.merge(config.config_files.map { |p| path.store(p) })
    end
    @validator = path.store.validator(path.store.merge(defaults, validator, config_files))
    config = validator

    path.config_dsl(defaults, validator) do
      config_root         :directory, lazy { [ '~/.chef', path.join(path.cwd, '.chef') ] }
      config_files        :files,     lazy { [ path.join(config_root, 'config.rb'), profile_config_file, user.config_file ] }

      profile             :string,    'default'
      profile_root        :directory, lazy { path.join(config_root, 'profiles') }
      profile_config_file :file,      lazy { path.join(profile_root, "profiles/#{profile}.rb") }

      chef_server :block do
        url  :directory,   'cheflocal:default'
        user :name,        lazy { config.user.name }
        key  :private_key, lazy { config.user.key }
      end

      web_clients do
        configure 'cheflocal:**' do
          authentication :none
        end
        # This is where we actually configure the web client: the chef_server block
        # just has username and key for convenience.
        configure '{resolve:/chef_server/url}' do
          authentication :chef do
            user :name,        lazy { config.chef_server.user }
            key  :private_key, lazy { config.chef_server.key }
          end
        end
      end

      keys_root :directory, lazy { [ path.join(config_root, 'keys'), '~/.ssh' ] }

      user :block do
        name :name
        key  :private_key, lazy { path.join(credentials_root, "#{name}{.pem|}") }
        config_file :file, lazy { path.join(config_root, "users/#{name}.rb") }
      end

      chef_repo :directory
    end
  end
end
```


## local mode

```ruby
module ChefLocal
  def for_filesystem(fs)
    # fs = <source of your choice>
    # Transform paths
    raw = path.pathmap(fs, {
      '{environments|roles}/*' => path.transform({
        :path => '\1/\2{.json|.rb}',
        # if both exist, you will get both back.  Parent will resolve, returning first result first.
        :get => proc do |path, value|
          if path.extname == '.json'
            JSON.parse(value, :create_additions => false)
          else
            Rubyizer.from_ruby(path, value)
          end
        end,
        :set => proc do |path, value, set_value|
          if path.extname == '.json'
            set_value = JSON.pretty_generate(value)
          else
            set_value = Rubyizer.to_ruby(path, value)
          end
        end
      }),
      '{clients|data/{*}|nodes|users}/*' => path.transform({
        :path => '\1/\3{.json|.rb}',
        :get => proc { |path, value| JSON.parse(value, :create_additions => false) },
        :set => proc { |path, value, set_value| set_value = JSON.pretty_generate(value) }
      }),
      # Everything else, we get raw
      '**' => path.passthrough
    })
    #
    # Adding chef defaults
    #
    with_defaults = path.pathmap(fs, {
      'clients/*'
    })
    #
    # Fake endpoints for everything!
    #
    osc = path.store.pathmap(osc) {

    }
  end
end
```

```ruby
# pathblazer/init/cheflocal.rb
require 'chef_local'
Pathblazer::Register('cheflocal', proc do |context, url|
  ChefLocal.for_filesystem()
end)
```

```ruby
# pathblazer/filters/init/chef.rb
class Chef::Authentication
  def initialize(context, url, url_config)
    @user = url_config.authentication.user
    @key = url_config.authentication.key
  end

  def modify_request(type, path, *options)
    type, path, options[:headers] = ...
  end
end
```

Calling it:

```ruby
node = Chef::Context.global.chef_api.get('nodes') # or my_context.chef_api.get('nodes')
node['name']
```

##
How initial configuration is loaded:



## Defaults
# local mode
# credentials
# validation
# plugins
# profiles
# backcompat
# ssh certificates

local mode

To look like a Chef server, we want to get data into a format like this:

```ruby
module ChefServerDSL
  def chef_server_from_json(source)
    pathmap(source, :first_match_only, {
      chef_server_endpoints => from_json
    })
  end

  def from_json
    transform(
      :get => proc { |path, value| JSON.parse(value, :create_additions => false) },
      :set => proc { |path, value| JSON.pretty_generate(value) }
    )
  end

  def chef_repo_to_common(source)

  end

  def chef_repo_org_endpoints
    pathmap(source, :first_match_only, {

    })
  end

  def chef_repo_to_common
  end

  protected

  # This is a description of our model of the Chef server.
  def chef_endpoints
    org_endpoints = {
      'organization{s,}'     => acl_endpoint,
      'association_requests' => %w(count *),
      'clients'              => named_endpoint,
      'cookbooks'            => { '*' => [ acl_endpoints, '*' ] },
      'data'                 => { '*' => [ acl_endpoints, '*' ] },
      'environments'         => {
        '_acl'                  => []
        '{_default,*}'          => %w(cookbooks cookbooks/* cookbook_versions nodes recipes roles roles/*)
      },
      'groups'               => '{admins,billing-admins,users,clients,*}',
      'nodes'                => named_endpoint,
      'roles'                => named_endpoint,
      'sandboxes'            => named_endpoint,
      'search'               => '{environments,nodes,roles,*}',
      'users'                => '*',
      'principals/*'         => [],
      '_validator_key'       => [],
    }
    org_endpoints = {

    }
  end

  # This is a mapping between the Chef server model and ours.
  def chef_server_to_chef_acls(source, acl_source)
    pathmap(:first_match_only, {
      '**/_acl**' => redirect_to()
      '/organizations/*/organization{s,}/_acl**' => redirect_to(acl_source, '/organizations/\1\3'),
      '**' => '**' => redirect_to(source)
    })
  end

  # This is a complete description of a Chef server's endpoints.
  def chef_server_endpoints
    acl_endpoints = { '_acl' => %w(create read update delete grant) }
    named_endpoint = { '*' => acl_endpoints }
    org_endpoints = {
      'organization{s,}'     => acl_endpoint,
      'association_requests' => %w(count *),
      'clients'              => named_endpoint,
      'cookbooks'            => { '*' => [ acl_endpoints, '*' ] },
      'data'                 => { '*' => [ acl_endpoints, '*' ] },
      'environments'         => {
        '_acl'                  => []
        '{_default,*}'          => %w(cookbooks cookbooks/* cookbook_versions nodes recipes roles roles/*)
      },
      'groups'               => '{admins,billing-admins,users,clients,*}',
      'nodes'                => named_endpoint,
      'roles'                => named_endpoint,
      'sandboxes'            => named_endpoint,
      'search'               => '{environments,nodes,roles,*}',
      'users'                => '*',
      'principals/*'         => [],
      '_validator_key'       => [],
    }

    pathset(
      'authenticate_user',
      'system_recovery',
      'organizations' => { '*' => org_endpoints },
      'users' => {
        '*' => [ 'organizations', 'association_requests', 'association_requests/*' ]
      }
    )
  end
end
```
store_map({

})


knife

chef-zero



chef-metal
