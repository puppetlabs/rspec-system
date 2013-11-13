2.7.2
=====

This bug fixes ensures all SocketErrors for SSH are caught and retried.

It also fixes the last release whereby Net::SSH::Exception was accidentally
removed at release time.

#### Detailed Changes

* rescue and retry ssh on SocketError and Net::SSH::Exception (Johan Haals)

-------------------------------

2.7.1
=====

This bug fixes ensures all Net::SSH::Exceptions are caught and retried.

#### Detailed Changes

* catch all Net::SSH exceptions (Johan Haals)

-------------------------------

2.7.0
=====

This is a minor feature release that provides the necessary settings for a
linked clone when cloning images in VSphere.

#### Detailed Changes

* Use vsphere linked cloning (Ken Barber)

-------------------------------

2.6.0
=====

This is a feature release that improves a number of areas:

* Split out vagrant commonalities into a vagrant_base class
* Add support for vagrant-vmware_fusion
* Fix vagrant so we log in as root, not log in as vagrant and sudo
* Break out steps in providers: launch, connect, configure
* Generalise the SSH connection routines
* Provide a series of global configuration steps, like ntp sync, hostname
  fixups etc.
* Deprecated the internal_helpers module, its better to avoid global
  methods anyway
* Switched to using RS_ as the prefix for environment variables

#### Detailed Changes

* Refactor with some new features (Ken Barber)
* fix multi-node sample in readme (Pall Valmundsson)
* remove unnecessary if statment (Johan Haals)

-------------------------------

2.5.1
=====

This bug release fixes setting the hostname and /etc/hosts setup for VSphere.

-------------------------------

2.5.0
=====

This feature release improves the VSPhere provider.

* Additional settings have been provided to manage the deployment of nodes in VSphere
* Extra settings added to control timeouts and retries
* The main resiliency code has been overhauled and now we have retry handling for most external calls

#### Detailed Changes

* Repair vsphere provider (Ken Barber)

-------------------------------

2.4.0
=====

This feature release contains a number of new features:

* We now have an 'options' parameter for a node definition which allows customisation of the ip address, number of CPUs and amount of memory for a node. Currently this is only accepted for the Vagrant/Virtualbox provider.
* Dynamic loading of node_set plugins is now provided. This drops the requirement for having to 'require' the plugin to load it.

#### Detailed Changes

* (GH-44) Add 'options' parameter to node definition (Justen Walker)
* (GH-44) Support custom options for Vagrantfiles (Justen Walker)
* Fix wrong reference in README. (Stefano Zanella)
* Fix typo in example test code. (Stefano Zanella)
* Add 'ip' option to the 'options' parameter for node definitions (Trey Dockendorf)
* Add a simple plugin loading system for node_set plugins (Erik Dalén)

-------------------------------

2.3.0
=====

Rework the look and feel to make it pretty and add color

This feature release is primarily a look and feel update that improves the visual look of
how tests run. It changes the way `shell` and `rcp` output looks and includes
more color where applicable.

The output now uses the formatters output methods, in a mildly hackish way so
that colors can be disabled centrally and also so if users switch to a different
format the output is silenced. This is useful for cases where you want to run
the progress formatter without all the extra noise for example.

The dividers are now a little better, showing you the begin and end of blocks
in a better way now, so it is slightly easier to see before/after runs
without them bleeding into the test parts.

As an aside I've also migrated the scp methodology from vsphere to vagrant so
we are using the same channel to transfer files as well as for sending commands
which should in theory be a perf boost, but as yet I've seen little evidence.

#### Detailed Changes

* Rework the look and feel to make it pretty and add color (Ken Barber)

-------------------------------

2.2.1
=====

This minor fix release converts the Vagrant/Virtualbox provider to use version 2 of the configuration format, fixing some bugs in relation to warnings being printed to STDOUT instead of STDERR.

-------------------------------

2.2.0
=====

This feature release adds the ability to pass a node as a string to helpers, and improves documentation on multi-node support.

#### Detailed Changes

* Rename system_node to node in yarddoc (Ken Barber)
* Add support for passing a node name as a string to the :node meta-parameter (Ken Barber)
* Document basic multi-node usage (Ken Barber)
* Created an FAQ section and included info about serverspec (Ken Barber)

-------------------------------

2.1.2
=====

A meta-data only release, which adds the license to the gem specification.

-------------------------------

2.1.1
=====

This bug fix adds lsb_* facts to the prefabs for: centos-64 and fedora-18

#### Detailed Changes

* Add some missing facts (Mickaël Canévet)

-------------------------------

2.1.0
=====

This is a small feature release, that includes the ability for custom prefabs to be 'merged' with the inbuilt ones. This is a convenience, so that one can override the box definitions without having to also provide new Fact details (for example).

#### Detailed Changes

* Bundle exec should be used (Hunter Haugen)
* Align bundler instructions based on @hunner previous patch (Ken Barber)
* Perform deep merge of custom prefabs (Dominic Cleal)
* Fix yard doc error for Helpers (Ken Barber)

-------------------------------

2.0.0
=====

This major release adds some syntactical sugar, providing the user with the ability to use helpers in subjects.

So for example, where before you could use `shell` as a helper:

    describe 'shell tests' do
      it 'test 1' do
        shell('cat /etc/hosts') do |r|
          r.stdout.should =~ /localhost/
          r.stderr.should be_empty
          r.exit_code.should be_zero
        end
      end
    end

Now you can use it as the subject of a `describe` or `context`:

    describe 'shell tests' do
      context shell 'cat /etc/hosts' do
        its(:stdout) { should =~ /localhost/ }
        its(:stderr) { should be_empty }
        its(:exit_code) { should be_zero }
      end
    end

The helper `rcp` has also been modified to benefit from this change:

    describe 'rcp tests' do
      context rcp :dp => '/tmp/foo', :sp => '/tmp/foo' do
        its(:success) { should be_true }
      end
    end

The fact that you can use the helpers in both places should provide the user with greater flexibility to create more succinct tests, while still providing simple sequences of commands in a single test when needed as before.

This facility is also available to other plugins by providing a new `RSpecSystem::Helper` object that can be extended to provide a new helper with all the syntactic sugar features as the core methods `shell` and `rcp`.

As part of this release, we have also removed some prior deprecations:

* The system_* methods no longer work: system_run, system_rcp and system_node
* system_setup_block no longer works.

Before upgrading, we suggest you upgrade to 1.7.0, paying heed to any deprecation warnings before upgrading to 2.0.0.

#### Detailed Changes

* Fix yarddoc for rcp (Ken Barber)
* Remove deprecations in prep for 2 (Ken Barber)
* More sugar through lazy helper object (Ken Barber)
* Fix 2 yard errors (Ken Barber)
* Minor improvements to tests and apidocs (Ken Barber)

-------------------------------

1.7.0
=====

This change adjusts the temporary path for vagrant projects to use a directory in your project `.rspec_system`. This way while debugging issues on your VM you do not need to scroll back to find the vagrant project, simply look in the local `.rspec_system`.

Now if you want to adjust this base directory to something else, you can use the directory RSPEC_SYSTEM_TMP.

#### Detailed Changes

* Change the tmp path for the vagrant_projects directory to be under projects root directory (Trey Dock)

-------------------------------

1.6.0
=====

This minor feature release now adds test counts to the rspec-system formatter, for example:

    Running test: 21 of 22

So you can see mid-flight where the testing is up to.

#### Detailed Changes

* Present test count in formatter (Ken Barber)

-------------------------------

1.5.0
=====

This release renames the helpers to something more succinct:

* shell (was system_run)
* rcp (was system_rcp)
* node (was system_node)

This patch also deprecates the system_setup_block in favour of before :suite instead.

In the next major release, the old helpers and system_setup_block will stop working so it is recommended to look out for the deprecation messages and adjust your code now so that the next major release (2.x) will continue to work.

#### Detailed Changes

* Deprecate usage of system_setup_block (Ken Barber)
* Rename old helpers to shell, node, rcp (Ken Barber)

-------------------------------

1.4.0
=====

This release adds the ability to provide a custom prefabs.yml.

To define custom prefabs you can now place a `.prefabs.yml` file in your projects root directory.

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
        vagrant:
          box: 'scientific-64-x64-vb4210-nocm'
          box_url: 'http://example.com/path/to/scientific-64-x64-vb4210-nocm.box'

This also supports overriding the built-in prefabs as well, in case you wish to use your own image files - or use a cache host for example.

#### Detailed Changes

* Allow overriding prefabs including using boxes on local system (Trey Dockendorf)

-------------------------------

1.3.0
=====

This release adds a new environment variable RSPEC_DESTROY, when set to false it stops the virtual machines from being destroyed. This is useful for debugging, so you can keep the virtual machine running and login after failures to dig deeper into the failed state if you so desire.

#### Detailed Changes

* Add an environment variale option, RSPEC_DESTROY. When set to 'no' or 'false' this prevents the VM from being destroy before and after a test. (Trey Dockendorf)
