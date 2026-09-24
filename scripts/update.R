source('scripts/load.R')
if(file.exists('.env')) readRenviron('.env')
args <- commandArgs(trailingOnly=TRUE)
arg <- function(name,default) {i <- match(name,args); if(is.na(i)) default else {if(i==length(args)) stop('Falta valor para ',name); args[i+1]}}
mode <- arg('--mode','monitor'); limit <- as.numeric(arg('--limit',if(mode=='monitor') 'Inf' else '5'))
stopifnot(mode %in% c('monitor','discover','full'),!is.na(limit),limit>0)
mock <- '--mock' %in% args; dry <- '--dry-run' %in% args
if(mock && !dry) stop('El modo mock exige --dry-run para impedir publicar datos simulados.')
db <- load_db(); validate_db(db)
initial <- db; started <- now(); run_id <- stable_id('run',started,Sys.getpid())
checked <- changed <- candidates <- errors <- 0L
cat('Inicio',mode,if(dry) '(dry-run)' else '',if(mock) '(mock)' else '', '\n')
if(mode %in% c('monitor','full')) {
  r <- monitor(db,limit,fetcher=if(mock) fixture_fetch else fetch_source,extractor=if(mock) fixture_extract else extract_source,run_id=run_id)
  db <- r$db; checked <- r$checked; changed <- r$changed; errors <- errors+r$errors
}
if(mode %in% c('discover','full')) {
  r <- discover(db,limit,searcher=if(mock) fixture_search else discover_search,fetcher=if(mock) fixture_fetch else fetch_source,extractor=if(mock) fixture_extract else extract_source,run_id=run_id)
  db <- r$db; candidates <- r$candidates; errors <- errors+r$errors
}
db <- apply_overrides(db,run_id=run_id)
db$runs <- rbind(db$runs,row('runs',run_id=run_id,started_at=started,finished_at=now(),mode=mode,sources_checked=checked,sources_changed=changed,candidates_found=candidates,records_added=nrow(db$opportunities)-nrow(initial$opportunities),records_updated=sum(flag(db$changes$auto_applied))-sum(flag(initial$changes$auto_applied)),review_items_created=nrow(db$review_queue)-nrow(initial$review_queue),errors=errors,status=if(errors) 'partial' else 'success'))
validate_db(db,verbose=TRUE)
if(!dry) save_db(db)
cat(sprintf('Fuentes: %s; cambios de contenido: %s; candidatos: %s; errores: %s.\n',checked,changed,candidates,errors))
if(dry) cat('Tablas canónicas intactas.\n')
if(errors>0 && checked+candidates==errors) quit(status=1)
