# rspec-system

`rspec-system` provides a framework for creating system tests using the `rspec` testing library.

The goal here is to provide facilities to aid in the launching of tests nodes, copying of test content to such nodes, and executing commands on such nodes to be tested with standard rspec assertions within the standard rspec test format.

*Note:* This library is fairly new at the moment, so your mileage may vary. That said, if you're good at ruby and have an opinion, I'd appreciate patches and improvements to move this further torwards stability.

### FAQ

#### What is this tool, and why do I need it?

`rspec-system` is a system testing tool that specializes in preparing test systems, running setup commands for a test and providing rspec helpers to assist with writing rspec assertions.

In short, it tests software on real systems. For realz. It doesn't mock the execution of anything. So you would use this software, if you want more complete guarantees around the ability to run your software on a real operating system.

For writing tests it uses the [rspec](https://www.relishapp.com/rspec) testing framework, used by many Ruby projects, your software however does not actually need to be written in Ruby - you just need to know a minimal amount of Ruby to write the tests.

#### Can this tool be used to test Puppet?

Yes it can. Check out the plugin: [rspec-system-puppet](http://rubygems.org/gems/rspec-system-puppet).

#### How does this tool overlap with serverspec?

`rspec-system` and `serverspec` are similar tools built to solve different testing perspectives. `serverspec` is aimed at validating a running environment with great tests and matchers that are made simple for administrators to write. `rspec-system` is an integration/system testing suite more then for built system validation. It is also used for testing a running environment, but its focus is more around testing system tools (such as Puppet for example) by launching nodes, setting up the software in question and performing tests on it. Thus `rspec-system` is appropriate for testing a piece of software, whereas `serverspec` is for validating a test or production system that has been built by some outside force.

Of course the overlap is in what these tools do ultimately. `serverspec` logs into systems and runs commands to achieve its tests, and `rspec-system` is no different. However we have recognized `serverspec`'s strengths at the 'testing' end of the phase, so we have built a bridge so you can use `rspec-system` in your dev projects but benefit from the power of the `serverspec` tests and matchers: [rspec-system-serverspec](http://rubygems.org/gems/rspec-system-serverspec).

### Gem installation

The intention is that this gem is used within your project as a development library.

Either install `rspec-system` manually with:

    gem install rspec-system

However it is usually recommended to include it in your `Gemfile` and let bundler install it, by adding the following:

    gem 'rspec-system'

Then installing with:

    bundle install --path vendor/bundle

If you're using git, add `.rspec_system` to your project's `.gitignore` file.  This is the default location for files created by rspec-system.

### Writing tests

Start by creating a helper file in `spec/spec_helper_system.rb` containing something like the following:

    require 'rspec-system/spec_helper'

    RSpec.configure do |c|
      c.before :suite do
        # Insert some setup tasks here
        shell 'yum install -y ntp'
      end
    end

Within this file we can fine tune the behaviour of rspec-system, but more importantly we can use the before :suite rspec hook to provide setup tasks that must occur before all your tests.

Create the directory `spec/system` in your project, its recommended to make sure your unit tests go into `spec/unit` instead so you can isolate them easily during test time. Add files with the spec prefix ie. `mytests_spec.rb` and make sure they always include the line `require 'spec_helper_system'`.

An example file would look like this:

    require 'spec_helper_system'

    describe 'basics' do
      # Here we use the 'shell' helper as a subject
      context shell 'cat /etc/hosts' do
        its(:stdout) { should =~ /localhost/ }
        its(:stderr) { should be_empty }
        its(:exit_code) { should be_zero }
      end

      it 'should cat /etc/hosts' do
        # Here we run the shell command as a helper
        shell 'cat /etc/hosts' do |r|
          r.stdout.should =~ /localhost/
          r.stderr.should be_empty
          r.exit_code.should be_zero
        end
      end
    end

Also consult the examples in the `examples` directory in the source of this library for more details.

Currently to get the nice formatting rspec-system specific formatter its recommended to use the Rake task, so add the following to your `Rakefile`:

    require 'rspec-system/rake_task'

That will setup the `spec:system` rake task.

### Creating a nodeset file

A nodeset file outlines all the node configurations for your tests. The concept here is to define one or more 'nodesets' each nodeset containing one or more 'nodes'. Create the file in your projects root directory as `.nodeset.yml`.

    ---
    default_set: 'centos-59-x64'
    sets:
      'centos-59-x64':
        nodes:
          'main.vm':
            prefab: 'centos-59-x64'
      'debian-607-x64':
        nodes:
          'main.vm':
            prefab: 'debian-607-x64'

The file must adhere to the Kwalify schema supplied in `resources/kwalify-schemas/nodeset_schema.yml`.

* `sets`: Each set contains a series of nodes, and is given a unique name. You can create sets with only 1 node if you like.
* `sets -> [setname] -> nodes`: Node definitions for a set. Each node needs a unique name so you can address each one individualy if you like.
* `sets -> [setname] -> nodes -> [name] -> prefab`: This relates to the prefabricated node template you wish to use. Currently this is the only way to launch a node. Look in `resources/prefabs.yml` for more details.
* `default_set`: this is the default set to run if none are provided with `bundle exec rake spec:system`. This should be the most common platform normally.

### Multi-node tests

With `rspec-system` you can launch and perform tests and setup actions on multiple nodes.

In your `.nodeset.yml` file you will need to define multiple nodes:

    ---
    sets:
      'centos-59-x64-multinode':
        default_node: 'first.mydomain.vm'
        nodes:
          'first.mydomain.vm':
            prefab: 'centos-59-x64'
          'second.mydomain.vm':
            prefab: 'centos-59-x64'

When you now run `rake spec:system` both nodes will launch.

Tests need to be written specifically with multi-node in mind however. Normally, helpers will try to use the first (and thus default) node only when executed. If you wish to use a helper against a particular node instead, you can use the `:node` metaparameter to specify execution on a particular node.

An example using the `shell` helper:

    shell(:node => 'second.mydomain.vm', :command => 'hostname')

This would execute the command `hostname` on node `second.mydomain.vm`.

### Custom node options

By default, `rspec-system` launches nodes with the settings that were baked into the prefab. This means that your node's physical properties like RAM and vCPU count depend on the prefab selected. If you need to customize these values, `rspec-system` provides node-level customization in `.nodeset.yml` under `options`.

Currently supported options are:

* *ip:* additional IP address
* *cpus:* number of virtual cpus
* *memory:* memory in MB

Example:

    ---
    sets:
      'centos-59-x64-multinode':
        nodes:
          default_node: 'first.mydomain.vm':
          'first.mydomain.vm':
            prefab: 'centos-59-x64'
            options:
              ip: '192.168.1.2'
              cpus: 2
              memory: 1024 #mb
          'second.mydomain.vm':
            prefab: 'centos-59-x64'
            options:
              ip: '192.168.1.3'
              cpus: 1
              memory: 512 #mb

*Note:* These options are currently only supported on Vagrant + VirtualBox. On other providers they are ignored.

### Prefabs

Prefabs are 'pre-rolled' virtual images, for now its the only way to specify a template.

The current built-in prefabs are defined in `resources/prefabs.yml`. The current set are based on boxes hosted on <http://puppet-vagrant-boxes.puppetlabs.com> as they have been built by myself and are generally trusted and have a reproducable build cycle (they aren't just 'golden images'). In the future I'll probably expand that list, but attempt to stick to boxes that we have control over.

Prefabs are designed to be generic across different hosting environments. For example, you should be able to use a prefab string and launch an EC2 or Vagrant image and find that the images are identical (or as much as possible). The goal should be that local Vagrant users should find their own local tests pass, and when submitting code this should not change for EC2.

For this reason there are various `provider_specific` settings that apply to different provider types. For now though, only `vagrant` specific settings are provided.

`facts` in the prefab are literally dumps of `facter -p` on the host stored in the prefab file so you can look them up without addressing the machine. These are accessed using the `node#facts` method on the helper results and can be used in conditional logic during test runs and setup tasks. Not all the facts are supplied, only the more interesting ones.

#### Custom Prefabs

To define custom prefabs place a `.prefabs.yml` file in your project's root directory.

    ---
    'scientific-64-x64':
      description: ""
      facts:
        kernelrelease: "2.6.32-358.el6.x86_64"
        operatingsystem: Scientific
        kernelmajversion: "2.6"
        architecture: x86_64
        facterversion: "1.7.0"
        kernelversion: "2.6.32"
        operatingsystemrelease: "6.4"
        osfamily: RedHat
        kernel: Linux
        rubyversion: "1.8.7"
      provider_specifics:
        vagrant_virtualbox:
          box: 'scientific-64-x64-vb4210-nocm'
          box_url: 'http://example.com/path/to/scientific-64-x64-vb4210-nocm.box'

#### Overriding Prefabs

The custom prefab file, `.prefabs.yml` can also be used to override any of the built-in Prefabs.

For example, to use a different box for CentOS 6.4 x64, you can override the `box_url`.  The example below overrides the URL to use the box with configuration management already installed.

    ---
    'centos-64-x64':
      provider_specifics:
        vagrant_virtualbox:
          box: 'centos-64-x64-vbox4210'
          box_url: 'http://puppet-vagrant-boxes.puppetlabs.com/centos-64-x64-vbox4210.box'

### Running tests

There are two providers at the moment you can use to launch your nodes for testing:

* Vagrant: for the local desktop to run during development and debugging mainly
* VSphere: for CI systems such as Jenkins

Although both systems can be used for either purpose, if you so desire.

Instead of switches, we use a number of environment variables to modify the behaviour of running tests. This is more inline with the way testing frameworks like Jenkins work, and should be pretty easy for command line users as well:

* *RS_PROVIDER* - defines the nodeset provider, for now `vagrant_virtualbox` is the default.
* *RS_SET* - the set to use when running tests (defaults to the `default_set` setting in the projects `.nodeset.yml` file). This string must align with the entries under `sets` in your `.nodeset.yml`.
* *RS_DESTROY* - set this to `no` if you do not want your nodes to be destroyed before or after a test completes.  May be useful during initial testing of rspec tests to allow inspection of the node.
* *RS_TMP* - This patch is used for various temporary content. Default is the directory `.rspec_system` in your projects root.
* *RS_SSH_TRIES* - Number of attempts to connect to a node using SSH. Defaults to 10.
* *RS_SSH_SLEEP* - Number of seconds between attempts. Defaults to 4.
* *RS_SSH_TIMEOUT* - Timeout for attempting SSH connectivity. Defaults to 60.

So if you wanted to run an alternate nodeset you could use:

    RS_SET=fedora18 bundle exec rake spec:system

In Jenkins you should be able to use RS\_SET in a test matrix, thus obtaining quite a nice integration and visual display of nodesets in Jenkins.

#### Vagrant Virtualbox

    RS_PROVIDER='vagrant_virtualbox'

This is the default provider, as all the products for this provider are free, most people should be able to run it.

Make sure you have already installed:

* VirtualBox 4.2.10+
* Vagrant 1.2.x+

Once these are ready, you can Run the system tests with:

    bundle exec rake spec:system

The VM's should be downloaded from the internet, started and tests should run.

#### Vagrant VMware Fusion

    RS_PROVIDER='vagrant_vmware_fusion'

Make sure you have already installed:

* VirtualBox 4.2.10+
* VMware Fusion 5.0.3+

Once these are ready, you can Run the system tests with:

    RS_PROVIDER='vagrant_vmware_fusion' bundle exec rake spec:system

The VM's should be downloaded from the internet, started and tests should run.

#### VSphere

    RS_PROVIDER='vsphere'

This provider will launch nodes using VMWare VSphere API's and use those for running tests. This provider is really aimed at the users who want to use this library within their own CI system for example, as apposed to developers who wish to run tests locally themselves.

This provider has a lot more options for setup, in the form of environment variables:

* *RS_VSPHERE_HOST* - hostname of your vsphere api
* *RS_VSPHERE_USER* - username to authenticate with
* *RS_VSPHERE_PASS* - password to authenticate with
* *RS_VSPHERE_DEST_DIR* - destination path to launch vm's
* *RS_VSPHERE_TEMPLATE_DIR* - path to where you deployed the templates from the OVF files described above
* *RS_VSPHERE_RPOOL* - name of resource pool to use
* *RS_VSPHERE_CLUSTER* - name of the cluster to use
* *RS_VSPHERE_SSH_KEYS* - path to private key for authentication. Multiple paths may be provided using a colon separator.
* *RS_VSPHERE_DATACENTER* - optional name of VSphere data centre
* *RS_VSPHERE_NODE_TIMEOUT* - amount of seconds before trying to relaunch a node. Defaults to 1200.
* *RS_VSPHERE_NODE_TRIES* - amount of attempts to relaunch a node. Defaults to 10.
* *RS_VSPHERE_NODE_SLEEP* - amount of seconds to sleep for before trying again. Defaults to a random number between 30 and 90.
* *RS_VSPHERE_CONNECT_TIMEOUT* - amount of seconds before retrying to connect to the VSphere API. Defaults to 60.
* *RS_VSPHERE_CONNECT_TRIES* - amount of attempts to connect to the VSphere API. Defaults to 10.

Set these variables, and run the usual rake command specifying the provider:

    RS_PROVIDER='vsphere' bundle exec rake spec:system

In Jenkins, set the authentication variables above using environment variable injection. I recommend using the private environment variables feature for user & pass however so these do not get displayed in the console output. As with the vagrant provider however, turn RS\_SET into a test matrix, containing all the sets you want to test against.

#### OpenStack

You may also use [OpenStack](http://www.openstack.org/) as a virtualization provider.

    RS_PROVIDER=openstack

All parameters are required and case sensitive.

* *RS_OPENSTACK_ENDPOINT* -- Your openstack token url, something like `http://your.openstack.url:5000/v2.0/tokens`
* *RS_OPENSTACK_USERNAME* -- Your openstack username
* *RS_OPENSTACK_API_KEY* -- password
* *RS_OPENSTACK_KEYPAIR_NAME* -- ssh keypair name
* *RS_OPENSTACK_FLAVOR_NAME* -- flavor name
* *RS_OPENSTACK_IMAGE_NAME* -- image name
* *RS_OPENSTACK_NETWORK_NAME* -- network name
* *RS_OPENSTACK_NODE_TIMEOUT* -- Number of seconds to wait for openstack instances to be created
* *RS_OPENSTACK_SSH_KEYS* -- Full path to ssh private keys, colin (:) delimited


##### OpenStack TODO
* Support `RSPEC_DESTROY=no` and destroying abandoned instances by persisting the server ids in .rspec_system
* Provide support for floating ips
* Support explicit tenant ids
* No custom option support

### Plugins to rspec-system

Right now we have two types of plugins, the framework is in a state of flux as to how one writes these things but here we go.

#### Helper libraries

Libraries that provide test helpers, and setup helpers for testing development on the software in question.

* [rspec-system-puppet](http://rubygems.org/gems/rspec-system-puppet) - Helpers for testing out Puppet plugins
* [rspec-system-serverspec](http://rubygems.org/gems/rspec-system-serverspec) - Imports the serverspec helpers and matchers so they can be used in rspec-system.

#### Node providers

A node provider should provide the ability to launch nodes (or if they are already launched provide information to get to them), run commands on nodes, transfer files and shutdown nodes. That is, abstractions around other virtualisation, cloud or system tools.

Right now the options are:

* vagrant\_virtualbox
* vagrant\_vmware\_fusion
* vsphere

... and these are installed with core. In the future we probably want to split these out to plugins, but the plugin system isn't quite ready for that yet.

#### The Future of Plugins

I want to start an eco-system of plugins for rspec-system, but do it in a sane way. Right now I see the following potential plugin types, if you think you can help please do:

* node providers - that is, abstractions around other virtualisation, cloud or system tools. Right now a NodeSet is tied to a virtual type, but I think this isn't granual enough. Some ideas for future providers are:
    * other vagrant plugins - it should be reasonably easy to extend support out to new vagrant plugins, since most of the example plugins are already using a simple pattern to do this.
    * razor - for launching bare metail nodes for testing purposes. Could be really useful to have baremetal tests for software that needs it like `facter`.
    * manual - not everything has to be 'launched' I can see a need for defining a static configuration for older machines that can't be poked and peeked. Of course, we might need to add cleanup tasks for this case.
* helper libraries - libraries that provide test helpers, and setup helpers for testing development on the software in question.
    * distro - helpers that wrap common linux distro tasks, like package installation.
    * mcollective - for launching the basics, activemq, broker clusters. Useful for testing mcollective agents.
    * puppetdb - helpers for setting up puppetdb, probably using the modules we already have.
    * other config management tools - for the purposes of testing modules against them, or using them for test setup provisioners like I've mentioned before with Puppet.
    * others I'm sure ...

These could be shipped as external gems, and plugged in to the rspec-system framework somehow. Ideas on how to do this properly are very welcome, especially if you bring code as well :-).

### CI Integration

So currently I've only integrated this with Jenkins. If you have luck doing it on other CI platforms, feel free to add to this documentation.

#### Jenkins

For virtualbox the setup tested with was:

* Single box - 32GB of RAM and 8 cpus
* Debian 7
* Jenkins 1.510 (installed via packages from the jenkins repos)
* Vagrant 1.1.5 (installed via packages from the vagrant site)
* VirtualBox 4.2.10 (installed via packages from virtualbox)
* RVM with Ruby 2.0.0

Or for VSphere:

* Debian 7
* Jenkins 1.510
* VSphere 5.1 'cloud'

The setup for a job is basically:

* Create new matrix build
* Specify VCS settings etc. as per normal
* Create a user defined axis called 'RS\_SET' and add your nodesets in there: fedora-18-x64, centos-64-x64 etc.
* Use touchstone with a filter of RS\_SET=='centos-64-x64' so you don't chew up cycles running a whole batch of broken builds
* For the provider in question, make sure you have provided any custom configuration. For example VSphere requires a bunch of RS\_VSPHERE\_\* variables to be set. Make sure these are set using the environment variable injection facility.
* Create an execute shell job like so:

        #!/bin/bash
        set +e

        [[ -s "$HOME/.rvm/scripts/rvm" ]] && source "$HOME/.rvm/scripts/rvm"
        rvm use ruby-2.0.0
        bundle install --path vendor/bundle
        bundle exec rake spec:system

I went quite complex and had Github pull request integration working with this, and quite a few other nice features. If you need help setting it up get in touch.
