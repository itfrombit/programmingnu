;; site builder

(set $siteName "programming.nu")
(set $siteTitle "Programming Nu")
(set $siteSubtitle "Website for the Nu programming language.")
(set $siteDescription "The Nu Language Website")
(set $siteAddress "http://programming.nu")

(load "YAML")
(load "template")
(load "NuMarkdown")

(class NSObject (+ objectWithYAML:(id) yaml is (self fromYAML:yaml)))

(class NSString
     
     (- (id) markdownToHTML is (NuMarkdown convert:self)))
     
(class NSDictionary
     
     (- (id) bodyAsHTML is
        (set body (self valueForKey:"body"))
        (case (self valueForKey:"format")
              ("markdown" (body markdownToHTML))
              (else body)))
     
     (- (id) extendedAsHTML is
        (set extended (self valueForKey:"extended"))
        (case (self valueForKey:"format")
              ("markdown" (extended markdownToHTML))
              (else extended))))     

(class NSDate
     
     ;; Get a nice representation of a date for display.
     (- (id) descriptionForBlog is
        (self descriptionWithCalendarFormat:"%A, %d %b %Y"))
     
     ;; Get a y-m-d representation of a date.
     (- (id) ymd is
        (self descriptionWithCalendarFormat:"%Y-%m-%d"))
     
     (- (id) monthAndYear is
        (self descriptionWithCalendarFormat:"%B %Y"))
     
     ;; Get an RFC822-compliant representation of a date.
     (- (id) rfc822 is
        (set result ((NSMutableString alloc) init))
        (result appendString:
                (self descriptionWithCalendarFormat:"%a, %d %b %Y %H:%M:%S "
                      timeZone:(NSTimeZone localTimeZone) locale:nil))
        (result appendString:((NSTimeZone localTimeZone) abbreviation))
        result)
     
     ;; Get an RFC1123-compliant representation of a date.
     (- (id) rfc1123 is
        (set result ((NSMutableString alloc) init))
        (result appendString:
                (self descriptionWithCalendarFormat:"%a, %d %b %Y %H:%M:%S "
                      timeZone:(NSTimeZone timeZoneWithName:"GMT") locale:nil))
        (result appendString:((NSTimeZone timeZoneWithName:"GMT") abbreviation))
        result)
     
     ;; Get an RFC3339-compliant representation of a date.
     (- (id) rfc3339 is
        (set result ((NSMutableString alloc) init))
        (result appendString:
                (self descriptionWithCalendarFormat:"%Y-%m-%dT%H:%M:%S"
                      timeZone:(NSTimeZone localTimeZone) locale:nil))
        (set offset (/ ((NSTimeZone localTimeZone) secondsFromGMT) 3600))
        (cond ((< offset -9) (result appendString:"#{offset}:00"))
              ((< offset 0) (result appendString:"-0#{(* -1 offset)}:00"))
              (t (result appendString:"-0#{offset}:00")))
        result)
     
     (- (id) path is
        (self descriptionWithCalendarFormat:"%Y/%m/%d" timeZone:nil locale:nil)))

(macro render-partial
     (try
         (set __name (eval (car margs)))
         (set __result (eval (NuTemplate codeForString:(NSString stringWithContentsOfFile:"views/_#{__name}.nuhtml"))))
         (unless __result
                 ;; log expanded template for debugging
                 (puts "error in template _#{__name}.nuhtml")
                 (puts ((NuTemplate scriptForString:(NSString stringWithContentsOfFile:"views/_#{__name}.nuhtml")) stringValue)))
         __result
         (catch (__exception)
                (puts "error in template _#{__name}.nuhtml (#{(__exception name)} #{(__exception reason)})")
                "")))

(macro render-page
     (try
         (set __name (eval (car margs)))
         (eval (NuTemplate codeForString:(NSString stringWithContentsOfFile:"views/#{__name}.nuhtml")))
         (catch (__exception)
                (puts "error in template #{__name}.nuhtml (#{(__exception name)} #{(__exception reason)})")
                "")))

(macro render-xml
     (try
         (set __name (eval (car margs)))
         (eval (NuTemplate codeForString:(NSString stringWithContentsOfFile:"views/#{__name}.nuxml")))
         (catch (__exception)
                (puts "error in template #{__name}.nuxml (#{(__exception name)} #{(__exception reason)})")
                "")))

(puts "reading site description")

(set pages (array))
(set pageFiles ((NSString stringWithShellCommand:"ls pages") lines))
(puts (+ "reading " (pageFiles count) " pages"))
(pageFiles each:
     (do (pageFile)
         (set info (NSObject objectWithYAML:(NSString stringWithContentsOfFile:(+ "pages/" pageFile "/info.yml"))))
         (set body (NSString stringWithContentsOfFile:(+ "pages/" pageFile "/body.txt")))
         (set extended (NSString stringWithContentsOfFile:(+ "pages/" pageFile "/extended.txt")))
         (info setObject:body forKey:"body")
         (info setObject:extended forKey:"extended")
         (info setObject:(NSDate dateWithNaturalLanguageString:(info "creationDate")) forKey:"creationDate")
         (info setObject:YES forKey:"permanent")
         (pages << info)))

(set posts (array))
(set postFiles ((NSString stringWithShellCommand:"ls posts | sort -r") lines))
(puts (+ "reading " (postFiles count) " posts"))
(postFiles each:
     (do (postFile)
         (set info (NSObject objectWithYAML:(NSString stringWithContentsOfFile:(+ "posts/" postFile "/info.yml"))))
         (set body (NSString stringWithContentsOfFile:(+ "posts/" postFile "/body.txt")))
         (set extended (NSString stringWithContentsOfFile:(+ "posts/" postFile "/extended.txt")))
         (info setObject:body forKey:"body")
         (info setObject:extended forKey:"extended")
         (info setObject:(NSDate dateWithNaturalLanguageString:(info "creationDate")) forKey:"creationDate")
         (info setObject:(+ "/posts/" ((info "creationDate") path) "/" (info "permalink")) forKey:"linkForDate")
         (posts << info)))

(puts "building site")

;; create the site directory
(system "rm -rf site")
(system "mkdir -p site/public")
(system "cp nunja.nu site/site.nu")
(system "cp -rp assets/* site/public")

;; build the index page
(set index-page (render-page "index"))
(index-page writeToFile:"site/public/index" atomically:NO)
(index-page writeToFile:"site/public/index.html" atomically:NO)

;; render pages
(pages each:
       (do (post)
           (puts (+ "rendering " (post "permalink")))
           ((render-page "show") writeToFile:(+ "site/public/" (post "permalink")) atomically:NO)))

;; render posts
(posts each:
       (do (post)
           (puts (+ "rendering " (post "permalink")))
           (set path (+ "site/public/posts/" ((post "creationDate") path)))
           (system (+ "mkdir -p " path))
           ((render-page "show") writeToFile:(+ path "/" (post "permalink")) atomically:NO)))

;; render feeds
(set feedposts (posts subarrayWithRange:'(0 7)))

(let (path "site/public/xml/rss20")
     (system (+ "mkdir -p " path))
     ((render-xml "rss") writeToFile:(+ path "/feed.xml") atomically:NO))
(let (path "site/public/xml/atom10")
     (system (+ "mkdir -p " path))
     ((render-xml "atom") writeToFile:(+ path "/feed.xml") atomically:NO))

