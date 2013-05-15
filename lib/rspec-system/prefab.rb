module RSpecSystem
  # This object represents a prefab definition from the prefabs.yml file
  class Prefab
    attr_reader :name
    attr_reader :description
    attr_reader :facts
    attr_reader :provider_specifics

    # Return prefab object based on name
    def self.prefab(name, custom_prefabs_path)
      if File.exists?(custom_prefabs_path)
        custom_prefabs = YAML.load_file(custom_prefabs_path)
      else
        custom_prefabs = {}
      end

      prefabs = YAML.load_file(File.join(File.dirname(__FILE__), '..', '..', 'resources', 'prefabs.yml'))
      prefabs.merge!(custom_prefabs)
      raise "No such prefab" unless pf = prefabs[name]

      RSpecSystem::Prefab.new(
        :name => name,
        :description => pf['description'],
        :facts => pf['facts'],
        :provider_specifics => pf['provider_specifics']
      )
    end

    def initialize(options = {})
      @name = options[:name]
      @description = options[:description]
      @facts = options[:facts]
      @provider_specifics = options[:provider_specifics]
    end
  end
end
