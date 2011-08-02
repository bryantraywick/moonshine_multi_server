module Moonshine
  module MultiServer
    def default_web_stack
      recipe :apache_server
    end

    def standalone_web_stack
      recipe :default_web_stack
      recipe :default_system_config
      recipe :non_rails_recipes
    end
    
    def default_database_stack
      case database_environment[:adapter]
      when 'mysql', 'mysql2'
        recipe :mysql_server, :mysql_database, :mysql_user, :mysql_fixup_debian_start
      when 'postgresql'
        recipe :postgresql_server, :postgresql_user, :postgresql_database
      when 'sqlite', 'sqlite3'
        recipe :sqlite3
      end
    end
    
    def standalone_database_stack
      # Create the database from the current <tt>database_environment</tt>
      def mysql_database
        exec "mysql_database",
          :command => mysql_query("create database #{database_environment[:database]};"),
          :unless => mysql_query("show create database #{database_environment[:database]};"),
          :require => service('mysql')
      end
      def mysql_user
        ips = configuration[:mysql][:allowed_hosts] || []
        allowed_hosts = ips || []
        allowed_hosts << 'localhost'
        allowed_hosts.each do |host|
          grant =<<EOF
GRANT ALL PRIVILEGES
ON #{database_environment[:database]}.*
TO #{database_environment[:username]}@#{host}
IDENTIFIED BY \\"#{database_environment[:password]}\\";
FLUSH PRIVILEGES;
EOF
          exec "#{host}_mysql_user",
            :command => mysql_query(grant),
            :unless  => "mysql -u root -e ' select User from user where Host = \"#{host}\"' mysql | grep #{database_environment[:username]}",
            :require => exec('mysql_database')
        end
      end

      recipe :default_database_stack
      recipe :default_system_config
      recipe :non_rails_recipes
    end

    def default_application_stack
      recipe :default_web_stack
      recipe :passenger_gem, :passenger_configure_gem_path, :passenger_apache_module, :passenger_site
      recipe :rails_recipes, :rails_database_recipes
    end

    def standalone_application_stack
      recipe :default_application_stack
      recipe :default_system_config      
    end

    def default_system_config
      recipe :ntp, :time_zone, :postfix, :cron_packages, :motd, :security_updates, :apt_sources
    end

    def default_stack
      recipe :default_web_stack
      recipe :default_database_stack
      recipe :default_application_stack
      recipe :default_system_config
    end

    def rails_recipes
      case database_environment[:adapter]
      when 'mysql', 'mysql2'
        recipe :mysql_gem
      when 'postgresql'
        recipe :postgresql_gem
      end
      recipe :rails_rake_environment, :rails_gems, :rails_directories, :rails_logrotate
    end

    def rails_database_recipes
      recipe :rails_bootstrap, :rails_migrations
    end

    def non_rails_recipes
      # Set up gemrc and the 'gem' package helper, but not Rails application gems.
      def gemrc
        exec 'rails_gems', :command => 'true'
        gemrc = {
          :verbose => true,
          :gem => "--no-ri --no-rdoc",
          :update_sources => true,
          :sources => [ 'http://rubygems.org' ]
        }
        gemrc.merge!(configuration[:rubygems]) if configuration[:rubygems]
        file '/etc/gemrc',
          :ensure   => :present,
          :mode     => '744',
          :owner    => 'root',
          :group    => 'root',
          :content  => gemrc.to_yaml
      end

      def non_rails_rake_environment
        package 'rake', :provider => :gem, :ensure => :installed
        exec 'rake tasks', :command => 'true'
      end
      recipe :non_rails_rake_environment, :gemrc
      recipe :rails_directories, :rails_logrotate
    end
  end
end