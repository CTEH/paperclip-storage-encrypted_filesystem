module Paperclip
  module Storage
    module EncryptedFilesystem
      class Configuration
        attr_accessor :generate_key_proc, :process_key_proc_for_write, :process_key_proc_for_read
        attr_accessor :generate_iv_proc, :process_iv_proc_for_write, :process_iv_proc_for_read
        attr_accessor :before_encrypt_proc
        attr_accessor :after_decrypt_proc
      end
    end
  end
end