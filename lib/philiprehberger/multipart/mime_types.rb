# frozen_string_literal: true

module Philiprehberger
  module Multipart
    # Built-in MIME type detection from file extensions
    module MimeTypes
      TYPES = {
        # Text
        '.txt' => 'text/plain',
        '.html' => 'text/html',
        '.htm' => 'text/html',
        '.css' => 'text/css',
        '.csv' => 'text/csv',
        '.tsv' => 'text/tab-separated-values',
        '.xml' => 'text/xml',
        '.rtf' => 'text/rtf',
        '.md' => 'text/markdown',
        '.markdown' => 'text/markdown',
        '.yaml' => 'text/yaml',
        '.yml' => 'text/yaml',
        '.ics' => 'text/calendar',
        '.vcf' => 'text/vcard',
        '.vcard' => 'text/vcard',

        # JavaScript / JSON
        '.js' => 'application/javascript',
        '.mjs' => 'application/javascript',
        '.json' => 'application/json',
        '.jsonld' => 'application/ld+json',
        '.map' => 'application/json',

        # Images
        '.jpg' => 'image/jpeg',
        '.jpeg' => 'image/jpeg',
        '.png' => 'image/png',
        '.gif' => 'image/gif',
        '.bmp' => 'image/bmp',
        '.ico' => 'image/x-icon',
        '.svg' => 'image/svg+xml',
        '.webp' => 'image/webp',
        '.tiff' => 'image/tiff',
        '.tif' => 'image/tiff',
        '.avif' => 'image/avif',
        '.heic' => 'image/heic',
        '.heif' => 'image/heif',
        '.jxl' => 'image/jxl',
        '.apng' => 'image/apng',
        '.psd' => 'image/vnd.adobe.photoshop',

        # Audio
        '.mp3' => 'audio/mpeg',
        '.wav' => 'audio/wav',
        '.ogg' => 'audio/ogg',
        '.oga' => 'audio/ogg',
        '.flac' => 'audio/flac',
        '.aac' => 'audio/aac',
        '.m4a' => 'audio/mp4',
        '.wma' => 'audio/x-ms-wma',
        '.opus' => 'audio/opus',
        '.mid' => 'audio/midi',
        '.midi' => 'audio/midi',
        '.weba' => 'audio/webm',
        '.aiff' => 'audio/aiff',
        '.aif' => 'audio/aiff',

        # Video
        '.mp4' => 'video/mp4',
        '.m4v' => 'video/mp4',
        '.avi' => 'video/x-msvideo',
        '.mov' => 'video/quicktime',
        '.wmv' => 'video/x-ms-wmv',
        '.flv' => 'video/x-flv',
        '.mkv' => 'video/x-matroska',
        '.webm' => 'video/webm',
        '.ogv' => 'video/ogg',
        '.m2ts' => 'video/mp2t',
        '.m3u8' => 'application/vnd.apple.mpegurl',
        '.3gp' => 'video/3gpp',
        '.3g2' => 'video/3gpp2',
        '.mpg' => 'video/mpeg',
        '.mpeg' => 'video/mpeg',

        # Documents
        '.pdf' => 'application/pdf',
        '.doc' => 'application/msword',
        '.docx' => 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
        '.xls' => 'application/vnd.ms-excel',
        '.xlsx' => 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        '.ppt' => 'application/vnd.ms-powerpoint',
        '.pptx' => 'application/vnd.openxmlformats-officedocument.presentationml.presentation',
        '.odt' => 'application/vnd.oasis.opendocument.text',
        '.ods' => 'application/vnd.oasis.opendocument.spreadsheet',
        '.odp' => 'application/vnd.oasis.opendocument.presentation',
        '.epub' => 'application/epub+zip',
        '.pages' => 'application/vnd.apple.pages',
        '.numbers' => 'application/vnd.apple.numbers',
        '.keynote' => 'application/vnd.apple.keynote',

        # Archives
        '.zip' => 'application/zip',
        '.tar' => 'application/x-tar',
        '.gz' => 'application/gzip',
        '.gzip' => 'application/gzip',
        '.bz2' => 'application/x-bzip2',
        '.7z' => 'application/x-7z-compressed',
        '.rar' => 'application/vnd.rar',
        '.xz' => 'application/x-xz',
        '.zst' => 'application/zstd',
        '.br' => 'application/x-brotli',
        '.lz' => 'application/x-lzip',
        '.lz4' => 'application/x-lz4',
        '.tgz' => 'application/gzip',
        '.dmg' => 'application/x-apple-diskimage',
        '.iso' => 'application/x-iso9660-image',

        # Fonts
        '.woff' => 'font/woff',
        '.woff2' => 'font/woff2',
        '.ttf' => 'font/ttf',
        '.otf' => 'font/otf',
        '.eot' => 'application/vnd.ms-fontobject',

        # Programming / Data
        '.rb' => 'text/x-ruby',
        '.py' => 'text/x-python',
        '.java' => 'text/x-java-source',
        '.c' => 'text/x-c',
        '.cpp' => 'text/x-c++src',
        '.h' => 'text/x-c',
        '.hpp' => 'text/x-c++hdr',
        '.rs' => 'text/x-rust',
        '.go' => 'text/x-go',
        '.php' => 'text/x-php',
        '.swift' => 'text/x-swift',
        '.kt' => 'text/x-kotlin',
        '.ts' => 'text/typescript',
        '.tsx' => 'text/typescript',
        '.jsx' => 'text/javascript',
        '.sh' => 'application/x-sh',
        '.bash' => 'application/x-sh',
        '.zsh' => 'application/x-sh',
        '.bat' => 'application/x-msdos-program',
        '.ps1' => 'application/x-powershell',
        '.sql' => 'application/sql',
        '.graphql' => 'application/graphql',
        '.wasm' => 'application/wasm',
        '.toml' => 'application/toml',
        '.ini' => 'text/plain',
        '.cfg' => 'text/plain',
        '.conf' => 'text/plain',
        '.log' => 'text/plain',
        '.env' => 'text/plain',

        # Binary / Application
        '.bin' => 'application/octet-stream',
        '.exe' => 'application/vnd.microsoft.portable-executable',
        '.dll' => 'application/vnd.microsoft.portable-executable',
        '.so' => 'application/x-sharedlib',
        '.dylib' => 'application/x-sharedlib',
        '.deb' => 'application/vnd.debian.binary-package',
        '.rpm' => 'application/x-rpm',
        '.apk' => 'application/vnd.android.package-archive',
        '.msi' => 'application/x-msi',
        '.swf' => 'application/x-shockwave-flash',
        '.sqlite' => 'application/x-sqlite3',
        '.db' => 'application/x-sqlite3',
        '.dat' => 'application/octet-stream',
        '.class' => 'application/java-vm',
        '.jar' => 'application/java-archive',
        '.war' => 'application/java-archive',
        '.ear' => 'application/java-archive'
      }.freeze

      # Look up the MIME type for a filename based on its extension
      #
      # @param filename [String] the filename or path to look up
      # @return [String] the MIME type, or 'application/octet-stream' for unknown extensions
      def self.lookup(filename)
        ext = File.extname(filename.to_s).downcase
        TYPES.fetch(ext, 'application/octet-stream')
      end
    end
  end
end
