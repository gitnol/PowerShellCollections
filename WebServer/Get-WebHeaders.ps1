function Get-WebHeaders {
    <#
.SYNOPSIS
Liest HTTP Response-Header und Statuscode aus.
#>
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Url)

    try {
        $r = Invoke-WebRequest -Uri $Url -Method Head -MaximumRedirection 0 -ErrorAction Stop
    }
    catch {
        # Manche Server liefern bei HEAD Mist -> fallback GET
        $r = Invoke-WebRequest -Uri $Url -Method Get -MaximumRedirection 0 -ErrorAction Stop
    }

    $h = @{}
    foreach ($k in $r.Headers.Keys) { $h[$k.ToLowerInvariant()] = $r.Headers[$k] }

    [pscustomobject]@{
        Url        = $Url
        StatusCode = [int]$r.StatusCode
        Missing    = (@(
                'cache-control', 'content-security-policy', 'strict-transport-security', 'x-content-type-options', 'expires'
            ) | Where-Object { -not $h.ContainsKey($_) }) -join ', '
        HSTS       = $h['strict-transport-security']
        CSP        = $h['content-security-policy']
        Server     = $h['server']
    }
}

Get-WebHeaders -Url 'https://mydomain.com'


# BitSight Web Server Security Assessment. es sollten diese Element in den HTTP Response-Headern enthalten sein, um die Sicherheit zu erhöhen:
# Nur ein Beispiel, die genauen Header und Werte hängen von der Anwendung und den Anforderungen ab, aber hier sind einige wichtige Header, die oft empfohlen werden:
# - Cache-Control: no-cache, no-store, must-revalidate
# - Content-Security-Policy: default-src 'self'; script-src 'self' https://trusted.cdn.com; object-src 'none'; frame-ancestors 'none';
# - Strict-Transport-Security: max-age=31536000; includeSubDomains; preload
# - X-Content-Type-Options: nosniff
# - Expires: Thu, 01 Jan 1970 00:00:00 GMT

# Beispiel Apache-Konfiguration (in .htaccess) z.B. für eine statische Seite, die von BitSight empfohlenen Header enthält: (NICHT DYNAMISCHE SEITEN!)

# <IfModule mod_headers.c>
#   # --- BitSight "required" (plus sinnvolle Basics) ---
#   Header set X-Content-Type-Options "nosniff"
#   Header set Referrer-Policy "strict-origin-when-cross-origin"
#   Header set X-Frame-Options "DENY"

#   # X-XSS-Protection ist veraltet -> lieber aus, damit keine Nebenwirkungen
#   Header set X-XSS-Protection "0"

#   # CSP: moderat für statische Seiten
#   # - img-src erlaubt data: (SVG/Data-URIs), sonst alles nur 'self'
#   # - style-src erlaubt inline, weil statische Seiten das oft nutzen (wenn du kein Inline hast: 'unsafe-inline' raus)
#   Header set Content-Security-Policy "default-src 'self'; img-src 'self' data:; script-src 'self'; style-src 'self' 'unsafe-inline'; object-src 'none'; base-uri 'self'; frame-ancestors 'none'; upgrade-insecure-requests"

#   # --- Caching: HTML kurz, Assets lang ---
#   <FilesMatch "\.(html|htm)$">
#     Header set Cache-Control "max-age=0, must-revalidate"
#   </FilesMatch>

#   <FilesMatch "\.(css|js|mjs|json|xml|ico|svg|woff|woff2|ttf|otf|eot|png|jpg|jpeg|gif|webp|avif|pdf)$">
#     Header set Cache-Control "public, max-age=604800"
#   </FilesMatch>
# </IfModule>

# # Expires (BitSight required header) passend setzen – ohne "unset"
# <IfModule mod_expires.c>
#   ExpiresActive On

#   # HTML: sofort ablaufen lassen (revalidieren)
#   ExpiresByType text/html "access plus 0 seconds"

#   # Assets: 7 Tage
#   ExpiresByType text/css "access plus 7 days"
#   ExpiresByType application/javascript "access plus 7 days"
#   ExpiresByType text/javascript "access plus 7 days"
#   ExpiresByType image/svg+xml "access plus 7 days"
#   ExpiresByType image/png "access plus 7 days"
#   ExpiresByType image/jpeg "access plus 7 days"
#   ExpiresByType image/gif "access plus 7 days"
#   ExpiresByType image/webp "access plus 7 days"
#   ExpiresByType image/avif "access plus 7 days"
#   ExpiresByType font/woff2 "access plus 7 days"
#   ExpiresByType font/woff "access plus 7 days"
#   ExpiresByType application/pdf "access plus 7 days"
# </IfModule>




# ALTERNATIV:

# <IfModule mod_headers.c>
#   # ----------------------------------------------------------------------
#   # | Security Headers                                                   |
#   # ----------------------------------------------------------------------

#   # X-Content-Type-Options: Verhindert MIME-Type Sniffing
#   # Stellt sicher, dass Browser den Content-Type nicht erraten.
#   Header always set X-Content-Type-Options "nosniff"

#   # Content-Security-Policy (CSP): Schützt vor Cross-Site Scripting (XSS) und anderen Angriffen
#   # Dies ist eine strikte CSP. Sie müssen sie möglicherweise anpassen,
#   # wenn Sie externe Skripte, Stylesheets, Bilder etc. laden.
#   #
#   # Erlaubt:
#   # - Inhalte vom eigenen Ursprung ('self')
#   # - data: URLs (für inline Bilder wie Ihr SVG)
#   # - objects, embeds, applets werden komplett blockiert (object-src 'none')
#   # - base-Tag URLs werden auf den eigenen Ursprung beschränkt
#   # - Einbetten der Seite in iframes auf anderen Domains wird verhindert (frame-ancestors 'none')
#   # - Unsichere HTTP-Requests werden auf HTTPS upgegraded
#   Header always set Content-Security-Policy "default-src 'self' data:; object-src 'none'; base-uri 'self'; frame-ancestors 'none'; upgrade-insecure-requests"

#   # X-Frame-Options: Alternative/Ergänzung zu frame-ancestors für Clickjacking-Schutz
#   # Wenn Sie frame-ancestors in CSP haben, ist dies oft redundant, schadet aber nicht.
#   Header always set X-Frame-Options "DENY"

#   # X-XSS-Protection: Aktiviert den XSS-Filter in einigen Browsern
#   Header always set X-XSS-Protection "1; mode=block"

#   # Referrer-Policy: Kontrolliert, welche Referrer-Informationen gesendet werden
#   # "no-referrer-when-downgrade" ist ein guter Standard: Sendet Referrer bei gleicher Sicherheit (HTTPS->HTTPS)
#   # aber nicht bei Downgrade (HTTPS->HTTP), was Privatsphäre und Sicherheit verbessert.
#   Header always set Referrer-Policy "no-referrer-when-downgrade"


#   # ----------------------------------------------------------------------
#   # | Caching Headers                                                    |
#   # ----------------------------------------------------------------------

#   # Standardmäßig kein Cache für HTML-Dokumente und PHP-Dateien (falls vorhanden)
#   # Diese Dateien sollten immer frisch vom Server geladen werden, um aktuelle Inhalte zu gewährleisten.
#   <FilesMatch "\.(html|htm|php)$">
#       Header set Cache-Control "no-store, no-cache, must-revalidate"
#       Header set Pragma "no-cache"
#       Header set Expires "0"
#   </FilesMatch>

#   # Längerer Cache für statische Assets (Bilder, CSS, JS, Fonts)
#   # Browser werden angewiesen, diese Dateien für eine Woche zu cachen.
#   # "public" bedeutet, dass auch Proxy-Caches sie speichern dürfen.
#   # "immutable" (falls vom Browser unterstützt) bedeutet, dass die Ressource
#   # sich nicht ändern wird, solange ihr URL gleich bleibt.
#   # Dies ist ideal für Assets, die einen Versions-Hash im Dateinamen haben (z.B. style.c2a3b4.css).
#   <FilesMatch "\.(css|js|json|xml|ico|pdf|flv|swf|svg|eot|ttf|otf|woff|woff2)$">
#       Header set Cache-Control "max-age=604800, public"
#       Header unset Pragma
#       Header unset Expires
#   </FilesMatch>

#   <FilesMatch "\.(jpg|jpeg|png|gif|webp|avif)$">
#       Header set Cache-Control "max-age=604800, public"
#       Header unset Pragma
#       Header unset Expires
#   </FilesMatch>

#   # Optional: Wenn Ihre statischen Assets wirklich "immutable" sind (z.B. hashed filenames)
#   # Sie können "immutable" hinzufügen, um den Browser zu signalisieren, dass er die Datei
#   # während der max-age-Periode niemals revalidieren muss.
#   # <FilesMatch "\.(css|js|json|xml|ico|pdf|flv|swf|svg|eot|ttf|otf|woff|woff2|jpg|jpeg|png|gif|webp|avif)$">
#   #     Header set Cache-Control "max-age=604800, public, immutable"
#   #     Header unset Pragma
#   #     Header unset Expires
#   # </FilesMatch>

# </IfModule>