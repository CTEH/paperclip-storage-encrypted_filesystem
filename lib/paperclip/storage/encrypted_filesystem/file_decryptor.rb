module Paperclip
  module Storage
    module EncryptedFilesystem
      module FileDecryptor

        def decrypt(attribute, options={})
          path = send(attribute).path(options[:type])
          options[:key] ||= paperclip_encryption_key
          options[:iv]  ||= paperclip_encryption_iv
          decrypted = Encryptoid.decrypt_file(path, key: options[:key], iv: options[:iv])
          after_decrypt_proc = Paperclip::Storage::EncryptedFilesystem.configuration.after_decrypt_proc
          if after_decrypt_proc
            decrypted = after_decrypt_proc.call(decrypted, self)
          end
          decrypted
        end

      end
    end
  end
end