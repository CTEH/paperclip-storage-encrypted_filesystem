module Paperclip
  module Storage
    # Overwrite flush_writes to save encrypted content.
    # The instance that includes the attachment has to implement
    # a getter method: paperclip_encryption_key and a string column
    # paperclip_encryption_iv for the initialization vector.
    module EncryptedFilesystem
      include Filesystem

      class << self
        attr_writer :configuration
      end

      def self.configuration
        @configuration ||= Configuration.new
      end

      def self.configure
        yield configuration
      end

      def self.reset_config!
        @configuration = nil
      end

      def encryption_iv_attr
        @encryption_iv_attr ||= "#{name}_iv"
      end

      def encryption_key_attr
        @encryption_key_attr ||= "#{name}_key"
      end

      def flush_writes
        validate_instance_methods!
        @queued_for_write.each do |style_name, file|
          FileUtils.mkdir_p(File.dirname(path(style_name)))
          File.open(path(style_name), 'wb') do |new_file|
            data = file.read
            new_file.write encrypt!(data)
          end
          if @options[:override_file_permissions]
            resolved_chmod = (@options[:override_file_permissions] &~0111) || (0666 &~File.umask)
            FileUtils.chmod(resolved_chmod, path(style_name))
          end
          file.rewind
        end
        after_flush_writes
        @queued_for_write = {}
      end

      def encrypt!(data)
        @key_for_instance ||= Paperclip::Storage::EncryptedFilesystem.configuration.generate_key_proc.try(:call, instance, self) || Encryptoid.random_key
        @iv_for_instance ||= Paperclip::Storage::EncryptedFilesystem.configuration.generate_iv_proc.try(:call, instance, self) || Encryptoid.random_key
        key_processor = Paperclip::Storage::EncryptedFilesystem.configuration.process_key_proc_for_write
        processed_key = key_processor.call(@key_for_instance, instance, self)
        iv_processor = Paperclip::Storage::EncryptedFilesystem.configuration.process_iv_proc_for_write || key_processor
        processed_iv = iv_processor.call(@iv_for_instance, instance, self)
        instance.update_columns(encryption_iv_attr => processed_iv, encryption_key_attr => processed_key)
        before_encrypt_proc = Paperclip::Storage::EncryptedFilesystem.configuration.before_encrypt_proc
        if before_encrypt_proc
          data = before_encrypt_proc.call(data, instance, self)
        end
        Encryptoid.encrypt data, key: @key_for_instance, iv: @iv_for_instance
      end

      def decrypt(options={})
        path = path(options[:type])
        key_proc = Paperclip::Storage::EncryptedFilesystem.configuration.process_key_proc_for_read
        iv_proc = (Paperclip::Storage::EncryptedFilesystem.configuration.process_iv_proc_for_read || key_proc)
        unless options[:key]
          key = instance.send(encryption_key_attr)
          if key_proc
            key = key_proc.call(key, instance, self)
          end
          options[:key] = key
        end
        unless options[:iv]
          iv = instance.send(encryption_iv_attr)
          if iv_proc
            iv = iv_proc.call(iv, instance, self)
          end
          options[:iv] = iv
        end
        decrypted = Encryptoid.decrypt_file(path, key: options[:key], iv: options[:iv])
        after_decrypt_proc = Paperclip::Storage::EncryptedFilesystem.configuration.after_decrypt_proc
        if after_decrypt_proc
          decrypted = after_decrypt_proc.call(decrypted, instance, self)
        end
        decrypted
      end

      def validate_instance_methods!
        [encryption_key_attr, encryption_iv_attr].each do |method|
          msg = "The object using has_attached_file using encrypted_filesystem as storage should implement #{method}"
          raise ArgumentError.new(msg) unless instance.respond_to?(method)
        end
      end

    end
  end
end
