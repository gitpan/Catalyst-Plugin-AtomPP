use Module::Build;
# See perldoc Module::Build for details of how this works

Module::Build->new
    ( module_name       => 'Catalyst::Plugin::AtomPP',
      license           => 'perl',
      requires          => {
          Catalyst => '5.50',
          'XML::Atom' => 0,
      },
    )->create_build_script;
