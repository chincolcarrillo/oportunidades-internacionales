source('scripts/load.R')
if(file.exists('.env')) readRenviron('.env')
args <- commandArgs(trailingOnly=TRUE)
arg <- function(name,default) {i <- match(name,args); if(is.na(i)) default else {if(i==length(args)) stop('Falta valor para ',name); args[i+1]}}
role <- arg('--role','monitor'); limit <- suppressWarnings(as.integer(arg('--limit','5')))
stopifnot(role %in% c('discover','monitor','curate'),!is.na(limit),limit>0)
mock <- '--mock' %in% args; dry <- '--dry-run' %in% args
if(mock && !dry) stop('Mock exige --dry-run')
path <- arg('--queue','data/proposals')
db <- load_db(); validate_db(db)
run_id <- stable_id('run',now(),Sys.getpid(),role,Sys.getenv('GITHUB_RUN_ID'))
if(role=='curate') {
  proposals <- read_proposals(path)
  cached_extract <- function(text,url) {
    hash <- digest::digest(text,algo='sha256',serialize=FALSE)
    key <- stable_id('extraction',url,hash)
    file <- file.path('data/agent-evidence',paste0(key,'.json'))
    if(!mock && file.exists(file)) {
      saved <- jsonlite::read_json(file,simplifyVector=FALSE)
      stopifnot(identical(saved$url,url),identical(saved$evidence_hash,hash))
      return(saved$extraction)
    }
    x <- if(mock) fixture_extract(text,url) else extract_source(text,url)
    if(!dry) {
      dir.create(dirname(file),recursive=TRUE,showWarnings=FALSE)
      jsonlite::write_json(list(url=url,evidence_hash=hash,extracted_at=now(),extraction=x),
        file,auto_unbox=TRUE,pretty=TRUE,null='null',na='null')
    }
    x
  }
  result <- curate_proposals(db,proposals,cached_extract,limit)
  old_attempts <- db$agent_decisions$attempts[match(result$agent_decisions$proposal_id,db$agent_decisions$proposal_id)]
  decisions <- result$agent_decisions[is.na(old_attempts) | result$agent_decisions$attempts!=old_attempts,,drop=FALSE]
  new_changes <- result$changes[!result$changes$change_id %in% db$changes$change_id,,drop=FALSE]
  result$runs <- rbind(result$runs,row('runs',run_id=run_id,started_at=now(),finished_at=now(),mode='curate',
    sources_checked=sum(decisions$role=='monitor'),sources_changed=sum(decisions$status=='applied'),
    candidates_found=sum(decisions$role=='discover'),records_added=nrow(result$opportunities)-nrow(db$opportunities),
    records_updated=sum(flag(new_changes$auto_applied)),review_items_created=nrow(result$review_queue)-nrow(db$review_queue),
    errors=sum(decisions$status %in% c('retry','stale')),status=if(any(decisions$status %in% c('retry','stale','review'))) 'partial' else 'success'))
  validate_db(result)
  if(!dry) save_db(result)
  counts <- table(decisions$status)
  summary <- c('# Resultado de curaduría',paste('Ejecución:',run_id),
    paste('Propuestas disponibles:',length(proposals)),paste('Decisiones en este lote:',nrow(decisions)),
    paste(names(counts),as.integer(counts),sep=': '),
    paste('Iniciativas incorporadas:',nrow(result$opportunities)-nrow(db$opportunities)),
    paste('Cambios de campos:',nrow(new_changes)),
    'Detalle: data/canonical/changes.csv y agent_decisions.csv; evidencia: data/proposals y data/agent-evidence.',
    'Publicación: pendiente de decisión manual de la propietaria.')
  cat(paste(summary,collapse='\n'),'\n')
  summary_path <- Sys.getenv('GITHUB_STEP_SUMMARY')
  if(nzchar(summary_path)) cat(paste(summary,collapse='\n'),'\n',file=summary_path,append=TRUE)
} else {
  proposals <- if(role=='monitor') observe_monitor(db,limit,if(mock) fixture_fetch else fetch_source,run_id,'--force' %in% args) else
    observe_discover(db,limit,if(mock) fixture_search else discover_search,if(mock) fixture_fetch else fetch_source,run_id)
  if(!dry) for(p in proposals) write_proposal(p,path)
  cat(role,':',length(proposals),'propuestas;',if(dry) 'sin persistir' else 'base canónica intacta','\n')
  if(isTRUE(attr(proposals,'search_failed'))) {
    message <- 'Búsqueda incompleta: revisar clave, modelo o presupuesto. Propuestas previas conservadas.'
    if(length(proposals)) warning(message) else stop(message)
  }
}
