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
