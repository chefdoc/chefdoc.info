require 'fileutils'
require 'open-uri'
require 'retryable'
require 'rubygems/package'
require 'helpers'
require 'mixlib/archive'

module YARD
  module Server
    # Monkeypatch of serializer coming from yard
    class RubyDocServerSerializer < DocServerSerializer
      def initialize(command = nil)
        @asset_path = File.join('assets', command.library.to_s)
        super
        self.basepath = command.adapter.document_root
      end

      def serialized_path(object)
        if String === object
          File.join(@asset_path, object)
        else
          super(object)
        end
      end
    end

    class Commands::LibraryCommand
      def initialize(opts = {})
        super
        self.serializer = RubyDocServerSerializer.new(self)
      end
    end

    # This defines what we actually do for our own defined types
    # like supermarket.
    class LibraryVersion
      include Helpers
      attr_accessor :platform # TODO: Remove?
      attr_accessor :download_url
      attr_accessor :ridley

      protected

      def load_yardoc_from_supermarket
        if File.directory?(yardoc_file_for_supermarket)
          return if ready?
          raise LibraryNotPreparedError
        end

        # Remote cookbook from supermarket
        url = download_url
        puts "#{Time.now}: Downloading remote cookbook #{name} from supermarket #{url}"

        FileUtils.mkdir_p(source_path_for_supermarket)

        safe_mode = YARD::Config.options[:safe_mode]

        Thread.new do
          begin
            cb_archive = download_cookbook_from_supermarket(url)
            expand_cookbook(cb_archive)
            sanitize_cookbook

            generate_yardoc(safe_mode)
            clean_source(cb_archive)

            self.yardoc_file = yardoc_file_for_supermarket
          rescue OpenURI::HTTPError => e
            puts "#{Time.now}: ERROR WITH COOKBOOK! (#{e.message})"
            FileUtils.rmdir_rf(source_path_for_supermarket)
          end
        end
        raise LibraryNotPreparedError
      end

      def load_yardoc_from_chef_server
        if File.directory?(yardoc_file_for_chef_server)
          return if ready?
          raise LibraryNotPreparedError
        end

        puts "#{Time.now}: Downloading remote cookbook #{name} from chef_server."
        FileUtils.mkdir_p(source_path_for_chef_server)

        safe_mode = YARD::Config.options[:safe_mode]

        Thread.new do
          begin
            ridley.cookbook.download(name, version, source_path_for_chef_server)
            sanitize_cookbook

            generate_yardoc(safe_mode)

            self.yardoc_file = yardoc_file_for_chef_server
          rescue OpenURI::HTTPError => e
            puts "#{Time.now}: ERROR WITH COOKBOOK! (#{e.message})"
            FileUtils.rmdir_rf(source_path_for_chef_server)
          end
        end
        raise LibraryNotPreparedError
      end

      def cookbook_source_path
        File.join(::COOKBOOKS_PATH, name[0].downcase, name, version)
      end

      alias source_path_for_supermarket cookbook_source_path
      alias source_path_for_chef_server cookbook_source_path

      def source_yardoc_file
        File.join(source_path, Registry::DEFAULT_YARDOC_FILE)
      end

      alias yardoc_file_for_supermarket source_yardoc_file
      alias yardoc_file_for_chef_server source_yardoc_file

      def load_yardoc_file_for_supermarket
        return yardoc_file_for_supermarket if File.exist?(yardoc_file_for_supermarket)
        nil
      end

      def load_yardoc_file_for_chef_server
        return yardoc_file_for_chef_server if File.exist?(yardoc_file_for_chef_server)
        nil
      end

      private

      def generate_yardoc(safe_mode)
        opts = ['-n',
                '-q',
                safe_mode ? '--safe' : '',
                '--plugin chefdoc'].join(' ')
        sh "cd #{source_path} &&
           #{YARD::ROOT}/../bin/yardoc #{opts} '**/*.{rb,json}'",
           "Generating cookbook doc #{self}", true
      end

      # Gratefully taken from Berkshelf (https://github.com/berkshelf/berkshelf)
      # Stream the response body of a remote URL to a file on the local file system
      #
      # @param [String] target
      #   a URL to stream the response body from
      #
      # @return [Tempfile]
      def download_cookbook_from_supermarket(target)
        local = Tempfile.new('cookbook', source_path_for_supermarket)
        local.binmode

        Retryable.retryable(tries: 5, on: OpenURI::HTTPError, sleep: 0.5) do
          open(target, 'rb') do |remote|
            local.write(remote.read)
          end
        end

        local
      ensure
        local.close(false) unless local.nil?
      end

      def expand_cookbook(io)
        puts "Expanding remote cookbook #{to_s(false)} to #{source_path}..."

        puts Mixlib::Archive.new(io).extract(source_path)
      end

      # Mixlib::Archive extracts into a directory by the name of the archive.
      # We need to move all files from this directory to its parent
      # There are also some bad files which we need to make sure don't exist.
      def sanitize_cookbook
        puts "Sanitizing remote cookbook path to #{source_path}"

        # Define which elements should not be moved from the extracted cookbook.
        # PaxHeader is an archive artifact that exists in some older cookbooks.
        no_move = ['.', '..', 'PaxHeader'].map { |e| "#{source_path}/#{name}/#{e}" }
        to_move = Dir.glob("#{source_path}/#{name}/{.*,*}").reject do |i|
          no_move.include? i
        end

        FileUtils.mv to_move, source_path

        bad_files = [name, 'PaxHeader', '.yardopts'].map { |bf| "#{source_path}/#{bf}" }
        FileUtils.rm_rf bad_files
      end

      def clean_source(cb_archive)
        # For now just clean the archive file.
        # TODO: What else to clean? Or just leave it be...
        system "rm -f #{cb_archive.path}"
      end
    end
  end

  module CLI
    # Monkeypatch to define default options used for generating yard docs.
    class Yardoc
      def yardopts(file = options_file)
        list = IO.read(file).shell_split
        list.map { |a| %w(-c --use-cache --db -b --query).include?(a) ? '-o' : a }
      rescue Errno::ENOENT
        []
      end

      # def add_extra_files(*files)
      #   files.map! {|f| f.include?('*') ? Dir.glob(File.join(File.dirname(options_file), f)) : f }.flatten!
      #   files.each do |file|
      #     file = File.join(File.dirname(options_file), file) unless file[0] == '/'
      #     if File.file?(file)
      #       fname = file.gsub(File.dirname(options_file) + '/', '')
      #       options[:files] << CodeObjects::ExtraFileObject.new(fname)
      #     end
      #   end
      # end
    end
  end
end
