1.3.0
=====

This release adds a new environment variable RSPEC_DESTROY, when set to false it stops the virtual machines from being destroyed. This is useful for debugging, so you can keep the virtual machine running and login after failures to dig deeper into the failed state if you so desire.

#### Detailed Changes

* Add an environment variale option, RSPEC_DESTROY. When set to 'no' or 'false' this prevents the VM from being destroy before and after a test. (Trey Dockendorf)
