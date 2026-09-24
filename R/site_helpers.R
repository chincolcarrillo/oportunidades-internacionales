site_table <- function(x,visible=NULL) {
  if(!nrow(x)) return(htmltools::tags$p('No hay registros que cumplan estos criterios.'))
  links <- intersect(c('enlaces','fuente'),names(x))
  for(n in links) x[[n]] <- vapply(x[[n]],function(v) {
    urls <- split_urls(v)
    paste(vapply(urls,function(u) if(grepl('^https?://',u)) sprintf('<a href="%s" target="_blank" rel="noopener noreferrer">%s</a>',htmltools::htmlEscape(u,attribute=TRUE),htmltools::htmlEscape(domain_of(u))) else htmltools::htmlEscape(u),character(1)),collapse='<br>')
  },character(1))
  hidden <- if(is.null(visible)) integer() else which(!names(x) %in% visible)-1L
  labels <- gsub('_',' ',names(x)); labels <- paste0(toupper(substr(labels,1,1)),substr(labels,2,nchar(labels)))
  DT::datatable(x,colnames=labels,rownames=FALSE,filter='top',escape=which(!names(x) %in% links),extensions='Buttons',
    options=list(pageLength=10,scrollX=TRUE,autoWidth=TRUE,dom='Bfrtip',buttons=list(list(extend='colvis',text='Elegir columnas')),
      columnDefs=list(list(targets=hidden,visible=FALSE)),
      language=list(search='Buscar:',zeroRecords='Sin coincidencias',info='Registros _START_ a _END_ de _TOTAL_',infoEmpty='Sin registros',infoFiltered='(filtrados de _MAX_)',paginate=list(previous='Anterior','next'='Siguiente'))))
}
site_data <- function() {
  db <- load_db('../data/canonical')
  # Recompute states on render day, without touching canonical files.
  list(db=db,published=published_tables(db))
}
upcoming_calls <- function(db) {
  x <- merge(db$calls,db$opportunities,by='opportunity_id',suffixes=c('','.opportunity'))
  x <- x[!is.na(x$fecha_cierre) & !is.na(x$closing_evidence) & x$fecha_cierre>=as.character(today()) & flag(x$active_record) & x$elegibilidad_uchile!='No',,drop=FALSE]
  x[order(x$fecha_cierre),,drop=FALSE]
}
