require 'rex/parser/ini'

module Rex
  module Parser
    module NetSarang
      class NetSarangCrypto
        attr_accessor :version
        attr_accessor :username
        attr_accessor :sid
        attr_accessor :master_password
        attr_accessor :key

        # new(type, version, username, sid, master_password = nil)
        #
        # === Argument
        # === Options
        # :type              :: [Enum]   xshell or xftp.
        # :version           :: [String] Specify version of session file.
        # :username          :: [String] Specify username. This parameter will be used if version > 5.2.
        # :sid               :: [String] Specify SID. This parameter will be used if version >= 5.1.
        # :master_password   :: [String] Specify user's master password.
        def initialize(type, version, username, sid, master_password = nil)
          self.version = version.to_f
          self.username = username
          self.sid = sid
          self.master_password = master_password
          md5 = OpenSSL::Digest::MD5.new
          sha256 = OpenSSL::Digest::SHA256.new
          if (self.version > 0) && (self.version < 5.1)
            self.key = (type == 'xshell') ? md5.digest('!X@s#h$e%l^l&') : md5.digest('!X@s#c$e%l^l&')
          elsif (self.version >= 5.1) && (self.version <= 5.2)
            self.key = sha256.digest(self.sid)
          elsif (self.version > 5.2)
            if self.master_password.nil?
              self.key = sha256.digest(self.username + self.sid)
            else
              self.key = sha256.digest(self.master_password)
            end
          else
            raise 'Invalid argument: version'
          end
        end

        def encrypt_string(string)
          cipher = Rex::Crypto.rc4(key, string)
          if (version < 5.1)
            return Rex::Text.encode_base64(cipher)
          else
            sha256 = OpenSSL::Digest::SHA256.new
            checksum = sha256.digest(string)
            ciphertext = cipher
            return Rex::Text.encode_base64(ciphertext + checksum)
          end
        end

        def decrypt_string(string)
          if (version < 5.1)
            return Rex::Crypto.rc4(key, Rex::Text.decode_base64(string))
          else
            data = Rex::Text.decode_base64(string)
            ciphertext = data[0, data.length - 0x20]
            plaintext = Rex::Crypto.rc4(key, ciphertext)
            if plaintext.is_utf8?
              return [plaintext, true]
            else
              return [nil, false]
            end
          end
        end
      end

      def parser_xsh(ini)
        version = ini['SessionInfo']['Version']
        port = ini['CONNECTION']['Port'] || 22
        host = ini['CONNECTION']['Host']
        username = ini['CONNECTION:AUTHENTICATION']['UserName']
        password = ini['CONNECTION:AUTHENTICATION']['Password'] || nil
        [version, host, port, username, password]
      end

      def parser_xfp(ini)
        version = ini['SessionInfo']['Version']
        port = ini['Connection']['Port']
        host = ini['Connection']['Host']
        username = ini['Connection']['UserName']
        password = ini['Connection']['Password']
        [version, host, port, username, password]
      end
    end
  end
end
