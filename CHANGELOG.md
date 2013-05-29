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
