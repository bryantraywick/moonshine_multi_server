module Moonshine
  module Generators
    class MultiServerGenerator < Rails::Generators::Base
      KNOWN_ROLES = %w(app web database redis memcached mongodb dj sphinx)

      desc Pathname.new(__FILE__).dirname.join('..', '..', '..', '..', 'generators', 'moonshine_multi_server', 'USAGE').read

      argument :roles, :type => :array, :defaults => %w(app web database)

      def self.source_root
        @_moonshine_source_root ||= Pathname.new(__FILE__).dirname.join('..', '..', '..', '..', 'generators', 'moonshine_multi_server', 'templates')
      end


      def manifest
        plugin 'moonshine', :git => 'git://github.com/railsmachine/moonshine.git'
        generate 'moonshine', "--multistage"

        template 'base_manifest.rb', 'app/manifests/base_manifest.rb'

        template 'configuration_builders.rb', 'app/manifests/lib/configuration_builders.rb'

        @roles.each do |role|
          self.role = role

          template_file = if KNOWN_ROLES.include?(role)
                          "#{role}_manifest.rb"
                          else
                          'role_manifest.rb'
                          end

          template template_file, "app/manifests/#{role}_manifest.rb"
        end

        if mongodb?
          plugin 'moonshine_mongodb', :git => 'git://github.com/railsmachine/moonshine_mongodb.git'
        end

        if web?
          plugin 'moonshine_haproxy', :git => 'git://github.com/railsmachine/moonshine_haproxy.git'
          plugin 'moonshine_heartbeat', :git => 'git://github.com/railsmachine/moonshine_heartbeat.git'
        end

        if iptables?
          plugin 'moonshine_iptables', :git => 'git://github.com/railsmachine/moonshine_iptables.git'
        end

        if redis?
          plugin 'moonshine_redis', :git => 'git://github.com/railsmachine/moonshine_redis.git'
        end

        if sysctl?
          plugin 'moonshine_sysctl', :git => 'git://github.com/railsmachine/moonshine_sysctl.git'
        end

        if memcached?
          plugin 'moonshine_memcached', :git => 'git://github.com/railsmachine/moonshine_memcached.git'
        end

      end

      protected

      # super hax to make compatible with rails 2 generator, so we can set it in the role above, and have access to 'role'
      attr_accessor :role

      # FIXME metaprogram using KNOWN_ROLES?

      def app?
        @roles.include?('app')
      end

      def web?
        @roles.include?('web')
      end

      def database?
        @roles.include?('database')
      end

      def redis?
        @roles.include?('redis')
      end

      def memcached?
        @roles.include?('memcached')
      end

      def sphinx?
        @roles.include?('sphinx')
      end

      def mongodb?
        @roles.include?('mongodb')
      end

      def iptables?
        web? || mongodb? || sphinx? || redis? || memcached? || database?
      end

      def sysctl?
        redis? || database? || sphinx?
      end

    end
  end
end