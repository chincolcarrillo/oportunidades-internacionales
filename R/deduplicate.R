duplicate_matches <- function(db, name, institution, urls=character()) {
  o <- db$opportunities
  if (!nrow(o)) return(data.frame(opportunity_id=character(), reason=character()))
  hits <- list()
  add <- function(ids, reason) if (length(ids)) data.frame(opportunity_id=ids,reason=reason) else NULL
  hits[[1]] <- add(unique(db$sources$opportunity_id[db$sources$url %in% urls]),'url')
  hits[[2]] <- add(o$opportunity_id[norm(o$convocatoria)==norm(name) & norm(o$institucion_financiante)==norm(institution)],'institution_name')
  domains <- domain_of(urls)
  domain_ids <- db$sources$opportunity_id[db$sources$domain %in% domains]
  hits[[3]] <- add(o$opportunity_id[o$opportunity_id %in% domain_ids & norm(o$convocatoria)==norm(name)],'domain_name')
  distance <- as.numeric(adist(norm(name),norm(o$convocatoria))) / pmax(nchar(norm(name)),nchar(norm(o$convocatoria)),1)
  hits[[4]] <- add(o$opportunity_id[distance < .22],'fuzzy_review_only')
  result <- do.call(rbind,hits)
  if (is.null(result)) data.frame(opportunity_id=character(),reason=character()) else unique(result)
}
queue_review <- function(db, opportunity_id=NA_character_, call_id=NA_character_, source_id=NA_character_, reason, details) {
  id <- stable_id('review',opportunity_id,call_id,source_id,reason,details)
  if (!id %in% db$review_queue$review_id) db$review_queue <- rbind(db$review_queue,row('review_queue',review_id=id,opportunity_id=opportunity_id,call_id=call_id,source_id=source_id,reason=reason,details=details,created_at=now(),status='pending'))
  db
}
