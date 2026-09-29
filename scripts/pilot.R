# Bounded live pilot: keeps canonical data unchanged; archives a reviewable proposal.
source('scripts/load.R')
if(file.exists('.env')) readRenviron('.env')
Sys.setenv(OPENAI_MAX_CALLS='3')
db <- load_db(); baseline <- db
urls <- c('https://www.spencer.org/grant_types/small-research-grant',
          'https://wennergren.org/program/dissertation-fieldwork-grant/',
          'https://leakeyfoundation.org/grant/research/')
indices <- match(urls,db$sources$url); stopifnot(!anyNA(indices))
run_id <- stable_id('pilot',now()); results <- list()
out <- file.path('data/staging',paste0('pilot-',format(today(),'%Y%m%d')))
dir.create(out,recursive=TRUE,showWarnings=FALSE)
for(k in seq_along(indices)) {
  i <- indices[k]; src <- db$sources[i,,drop=FALSE]
  cat('Consultando',src$url,'\n')
  fetched <- fetch_source(src$url)
  result <- list(url=src$url,status=fetched$status,error=fetched$error %||% NA_character_)
  if(fetched$status==200 && is.null(fetched$error)) {
    x <- tryCatch(extract_source(fetched$text,src$url),error=function(e) {result$error <<- conditionMessage(e); NULL})
    if(!is.null(x)) {
      result$extraction <- x
      jsonlite::write_json(list(source=src,fetch=fetched,extraction=x),file.path(out,paste0('source-',k,'.json')),auto_unbox=TRUE,pretty=TRUE,na='null',null='null')
      selected <- db; selected$sources <- src
      r <- monitor(selected,limit=1,fetcher=function(url) fetched,extractor=function(text,url) x,run_id=run_id,force=TRUE)
      updated_sources <- db$sources; updated_sources[i,] <- r$db$sources[1,]
      db <- r$db; db$sources <- updated_sources
      cat('Extracción completada:',x$convocatoria,'\n')
    }
  }
  if(!is.na(result$error)) cat('Resultado:',result$error,'\n')
  results[[k]] <- result
}
validate_db(db,verbose=TRUE)
for(n in names(db)) write_csv(db[[n]],file.path(out,'proposed',paste0(n,'.csv')))
changes <- db$changes[!db$changes$change_id %in% baseline$changes$change_id,,drop=FALSE]
write_csv(changes,file.path(out,'proposed_changes.csv'))
jsonlite::write_json(results,file.path(out,'results.json'),auto_unbox=TRUE,pretty=TRUE,na='null',null='null')
stopifnot(identical(load_db(),baseline))
cat('API calls:',api_usage$calls,'; cambios propuestos:',nrow(changes),'; canónicos intactos.\n')
