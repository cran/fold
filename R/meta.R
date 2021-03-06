
#' Save Folded Format as CSV
#' 
#' Saves folded format as CSV.  Simply calls as.csv.data.frame.
#' 
#' @inheritParams csv::as.csv
#' @return invisible folded (x)
#' @import csv
#' @export
#' @seealso \code{\link{fold.data.frame}} \code{\link{as.folded.character}}
#' @examples 
#' library(magrittr)
#' library(csv)
#' data(eventsf)
#' eventsf %>% as.csv(tempfile())
as.csv.folded <- function(x,...){
  class(x) <- 'data.frame'
  csv::as.csv(x,...)
}

#' Coerce to Folded Format
#' 
#' Coerces to folded format.
#' 
#' @param x object
#' @param ... passed arguments
#' @export
#' @keywords internal
#' @seealso \code{\link{as.folded.character}} \code{\link{as.folded.folded}} \code{\link{as.folded.data.frame}}
as.folded <- function(x,...)UseMethod('as.folded')

#' Coerce to Folded from Character
#' 
#' Coerces to folded by treating character as a filepath.
#' 
#' @param x length-one character
#' @param ... passed arguments
#' @return folded dat.frame
#' @import csv
#' @export
#' @seealso \code{\link{as.csv.folded}} \code{\link{as.folded}}
#' @examples 
#' library(magrittr)
#' library(csv)
#' data(eventsf)
#' file <- tempfile()
#' eventsf %>% as.csv(file)
#' as.folded(file)
as.folded.character <- function(x,...){
  y <- csv::as.csv(x,...)
  y <- as.folded(y,...)
  y
}

#' Coerce to Folded from Folded
#' 
#' Coerces to folded from folded.  A non-operation.
#' @inheritParams as.folded
#' @return folded data.frame
#' @export
#' @keywords internal
#' @seealso \code{\link{fold.data.frame}} \code{\link{as.folded}}
as.folded.folded <- function(x,...)x

#' Coerce to Folded from Data Frame
#' 
#' Coerces to folded from data.frame.
#' 
#' Expects columns VARIABLE, META, and VALUE. Remaining columns are for classification and may be NA. Coerces VALUE to character. Removes duplicate records with warning. Sorts on non-VALUE columns by default. Assigns class \code{folded}.
#' @inheritParams as.folded
#' @param sort Should the result be sorted?
#' @return folded data.frame
#' @import dplyr
#' @importFrom rlang UQS
#' @export
#' @seealso \code{\link{fold.data.frame}} \code{\link{as.folded}}
as.folded.data.frame <- function(x, sort = TRUE, ...){
  constitutive <- c('VARIABLE','META','VALUE')
  extras <- setdiff(names(x),constitutive)
  stopifnot(all(constitutive %in% names(x)))
  x <- x[,c(constitutive,extras),drop = FALSE]
  y <- distinct(x, .keep_all = TRUE)
  if(nrow(y) < nrow(x)){
    message('removing duplicates')
    x <- y
  }
  nms <- setdiff(names(x), 'VALUE')
  y <- distinct(x, UQS(syms(nms)), .keep_all = TRUE)
  if(nrow(y) < nrow(x)){
    warning('removing unique values where keys are duplicated')
    x <- y
  }
  if(sort) x <-  sort.folded(x,...)
  class(x) <- c('folded','data.frame')
  x
}

#' Sort Folded
#' 
#' Sorts folded, using all non-VALUE columns, starting from the left.  If decreasing is TRUE, the resulting row order is reversed.
#' @param x folded
#' @param decreasing logical
#' @param ... ignored arguments
#' @return folded
#' @import dplyr
#' @export
#' @importFrom rlang syms
#' @importFrom rlang UQS
#' @seealso \code{\link{fold.data.frame}}
#' @examples 
#' library(magrittr)
#' data(eventsf)
#' eventsf %>% sort
sort.folded <- function(x, decreasing = FALSE,...){
  vars <- setdiff(names(x),'VALUE')
  x <-  dplyr::arrange(x, UQS(syms(vars)))
  if(decreasing) x <- x[rev(rownames(x)),]
  rownames(x) <- NULL
  x
}

#' Distill Something
#' 
#' Distills something.
#' @param x object
#' @param ... passed arguments
#' @export
#' @keywords internal
#' @seealso \code{\link{fold.data.frame}} \code{\link{distill.folded}} \code{\link{distill.data.frame}}
distill <- function(x,...)UseMethod('distill')

#' Distill Folded
#' 
#' Distills folded. Indirectly calls the data.frame method.
#' 
#' @inheritParams distill
#' @export
#' @keywords internal
#' @seealso \code{\link{distill}}
distill.folded <- function(x,...){
  class(x) <- setdiff(class(x),'folded')
  distill(x,...)
}

#' Distill a Data Frame
#' 
#' Distills a data.frame with respect to a variable.  Recovers everything known about the variable, recursively mining metadata.
#' @inheritParams distill
#' @param mission character
#' @param parent character
#' @import dplyr
#' @importFrom tidyr spread
#' @export
#' @keywords internal
#' @seealso \code{\link{distill}}
distill.data.frame <- function(
  x,
  mission,
  parent = character(0),
  ...
){
  res = data.frame()
  data <-  dplyr::filter(x, VARIABLE == mission & is.na(META))
  if(nrow(data)) {
    data <- tidyr::spread(data,VARIABLE,VALUE,convert = TRUE)
    data <- dplyr::ungroup(data)
    data <- dplyr::select(data,-META) 
    data <- .informative(data)
    res <- data
  }
  meta <-  dplyr::filter(x, VARIABLE == mission & is.defined(META))
  if(nrow(meta)){
    for(m in unique(meta$META)){
     # message('processing attribute ',m)
      me <- meta
      me <- dplyr::filter(me, META == m) 
      me <- tidyr::spread(me, META,VALUE) 
      me <- dplyr::ungroup(me)
      me <- dplyr::select(me, -VARIABLE)
      me <-  .informative(me)
      lineage <- c(parent,mission)
      # canonical <- c(lineage,m)
      canonical <- c(mission, m) # e.g. BLQ_LLOQ not DV_BLQ_LLOQ
      canonical <- paste(canonical,collapse = '_')
      names(me)[names(me) == m] <- canonical
      # mo <- distill.folded(x,mission = m,parent = lineage,...)
      # me <- weld(me, mo)
      enc <- all(encoded(me[[canonical]])) & length(me[[canonical]]) == 1
      if(!nrow(res))res <- me
      if(nrow(res) & !enc) res <- weld(res,me)
      if(nrow(res) &  enc) res <- decode(
        res,
        encoded = mission,
        encoding = me[[canonical]][[1]],
        decoded = canonical,
        ...
      )
      mo <- distill.data.frame(x,mission = m,parent = lineage,...)
      res <- weld(res, mo)
    }
  }
  res
}

#' Unfold an Object
#' 
#' Unfolds an object.
#' 
#' @param x object
#' @param ... passed arguments
#' @export
#' @keywords internal
#' @seealso \code{\link{unfold.folded}} 
unfold <- function(x,...)UseMethod('unfold')

#' Unfold a Folded Data.frame
#' 
#' Unfolds a folded data.frame, or part thereof.
#' 
#' By default, the entire data.frame is unfolded, possibly giving back something originally passed to fold().  If \dots is specified, only selected items (given as anonymous unquoted arguments) are unfolded.  Values stored as encodings are converted to factor. The result has a groups attribute: a character vector of column names in the result whose interaction makes rows unique.
#' 
#' @param x folded data.frame
#' @param ... variables to unfold, given as unquoted anonymous names
#' @param sort whether to sort the result by groups values
#' @return class 'unfolded': data.frame with a groups attribute (character)
#' @export
#' @seealso \code{\link{unfold}} 
#' @examples 
#' library(magrittr)
#' library(dplyr)
#' data(eventsf)
#' eventsf %>% unfold
#' eventsf %>% unfold(DV,PRED)
#' x <- events %>% 
#'   filter(CMT == 2) %>% 
#'   select(ID, TIME, TAD, DV, BLQ, LLOQ, SEX) 
#' x
#' attr(x,'groups') <- c('ID','TIME')
#' 
#' # less than 10 values of DV, so BLQ looks like an encoding
#' y <- x  %>% fold(meta=list(DV~BLQ,BLQ~LLOQ))
#' y %>% data.frame
#' 
#' # reducing the tolerance forces BLQ to match by groups (ID, TIME) instead of DV value
#' z <- x  %>% fold(meta=list(DV~BLQ,BLQ~LLOQ),tol=3)
#' z
#' 
#' # recursive unfold, since LLOQ is an attribute of BLQ, which is an attribute of DV
#' unfold(y)
#' unfold(z)
#' y %>% unfold(DV)
#' y %>% unfold(BLQ)
#' y %>% unfold(LLOQ)
#' y %>% unfold(SEX)
#' y %>% unfold(TAD)
#' y %>% unfold(DV,SEX)
#' y %>% unfold(TAD,SEX)
unfold.folded <- function(x, ..., sort = TRUE){
  args <- quos(...)
  args <- lapply(args, f_rhs)
  var <- args[names(args) == '']
  var <- sapply(var, as.character) # should be vector, but list() gives list()
  other <- args[names(args) != '']
  groups <- setdiff(names(x),c('VARIABLE','META','VALUE'))
  vars <- unique(x$VARIABLE[is.na(x$META)])
  if(length(var) == 0) var <- vars
#  var <- setdiff(var,groups) # groups may return zero-row data.frames which do not merge well
#  if(length(var) == 0) stop('no non-group variables selected')
  # much faster with grouped_df removed
  x <- data.frame(x, stringsAsFactors = FALSE,check.names = FALSE, fix.empty.names = FALSE)
  y <- lapply(
    var,
    function(v)do.call(
      distill,
      c(
        list(
        x = x,
        mission = v
      ),
      other # distill only passes these to decode.data.frame which does not use them
      )
    )
  )
  y <- y[sapply(y, function(i) nrow(i) > 0)]
  z <- metaMerge(y)
  groups <- intersect(groups,names(z))
  #groups <- union(groups, var)
  # attr(z,'groups') <- groups
  for(i in groups){
    xtra <- distill(x, mission = i)
    if(nrow(xtra)){
      xtra <- shuffle(xtra, intersect(groups, names(xtra))) # any groups move forward
      z <- merge(z, xtra, all.x = TRUE, sort = FALSE)
      z <- shuffle(z, names(xtra), after = i)
    }
  }
  if(length(z) == 0) z <- data.frame()
  groups <- intersect(groups,names(z))
  attr(z,'groups') <- groups
  if(sort & length(groups)) {
    lst <- c(z[groups], list(method = 'radix', na.last = FALSE))
    dex <- do.call(order, lst)
    z <- z[dex,,drop = FALSE]
  }
  class(z) <- c('unfolded','data.frame')
  z
}

shuffle <- function (x, who, after = NA){
  names(x) <- make.unique(names(x))
  who <- names(x[, who, drop = FALSE])
  nms <- names(x)[!names(x) %in% who]
  if (is.null(after)) 
    after <- length(nms)
  if (is.na(after)) 
    after <- 0
  if (length(after) == 0) 
    after <- length(nms)
  if (is.character(after)) 
    after <- match(after, nms, nomatch = 0)
  if (after < 0) 
    after <- length(nms)
  if (after > length(nms)) 
    after <- length(nms)
  nms <- append(nms, who, after = after)
  x[nms]
}
#' @export
dplyr::filter

#' Fold an Object
#' 
#' Folds an object. Methods are supplied for \code{data.frame} and \code{grouped_df}.
#' 
#' @param x object
#' @param ... passed arguments
#' @export
#' @keywords internal
#' @seealso 
#' \code{\link{fold.data.frame}} 
#' \code{\link{fold.grouped_df}} 
fold <- function(x, ... )UseMethod('fold')

#' Fold grouped_df
#' 
#' Folds a grouped_df. Reclassifies as data.frame and passes groups explicitly. Anonymous arguments over-ride stored groups.
#' @param x data.frame
#' @param ... unquoted column names whose interaction makes records unique. Included in result but not stacked. groups(x) by default.  Named arguments are passed along.
#' @param meta a list of formulas in the form object ~ attribute. Pass something with length 0 to suppress guessing.
#' @param simplify set to NA any groups values that do not help distinguish values, and remove resulting duplicate records
#' @param sort whether to sort the result
#' @param tol maximum number of categories for guessing whether to encode metadata; encoding will always be attempted if metadata (attr) or its referent (obj) is a factor
#' @return folded data.frame with columns VARIABLE, META, VALUE and any supplied grouping items.
#' @import dplyr
#' @importFrom tidyr spread
#' @importFrom tidyr gather
#' @seealso \code{\link{obj_attr.data.frame}}  \code{\link{fold.grouped_df}}
#' @export
fold.grouped_df <- function(
  x,
  ...,
  meta = obj_attr(x),
  simplify = TRUE,
  sort = TRUE,
  tol = 10
){
  args <- quos(...)  
  args <- lapply(args,f_rhs)
  grps <- args[names(args) == '']
  other  <- args[names(args) != '']
  grps <- sapply(grps, as.character) 
  if(!length(grps)) grps <- sapply(groups(x), as.character)
  x <- ungroup(x)
  class(x) <- 'data.frame'
  attr(x,'groups') <- grps # respected by fold.data.frame
  do.call(
    fold.data.frame,
    c(
      list(
        x = x,
        meta = meta,
        simplify = simplify,
        sort = sort,
        tol = tol
      ),
      other
    )
  )
}

#' Fold a Data Frame
#' 
#' Folds a data.frame. Stacks columns, while isolating metadata and capturing keys. 
#' 
#' See \code{package?fold} for micro-vignette.
#' 
#' A folded data.frame is formalized re-presentation of a conventional data.frame.  Items in the conventional form are of three conceptual types: data, metadata, and keys.  Data items contain the primary values, to be described.  Metadata gives additional details about the data items or values. Keys are grouping items; combinations of grouping values should uniquely identify each conventional record.
#' 
#' In the result, names of data items appear in VARIABLE, while values of data items are stacked in VALUE. Data items are all columns from the input not otherwise identified as metadata or keys.
#' 
#' Likewise, names of metatdata items appear in META, while the name of the described data item appears in VARIABLE.  Values of metadata items appear in VALUE.  The metadata VALUE will be an encoding (see package: encode) if there is exactly one unique metadata value corresponding to each unique data value, AND one of the two is a factor (or neither factor, but there are \code{tol} or fewer unique values of data, and multiple unique values of metadata). Metadata items are identified explicitly using a list of formulas, or implicitly by means of column naming conventions.
#' 
#' Grouping items that are present in the input persist in the result and serve as keys.  Both data and metadata values may have keys, but neither require them.  Keys are identified explicitly by supplying unnamed, unquoted arguments (non-standard evaluation).  Use \code{dplyr::group_by} to add groups that will be respected when \code{\link{fold.grouped_df}} (or generic) is called. Or supply a \code{groups} attribute to the data.frame, e.g. \code{attr(x,'groups') <- c('USUBJID','TIME')}.
#' 
#' By default, superflous keys (those that do not help distinguish data items) are removed on a per-data-item basis. Column order is used to resolve ambiguities: checking proceeds right to left, preferentially discarding keys to the right.
#'
#' Note that metadata items may describe other metadata items, recursively.  In practice, however, such complexity could be problematic and is best avoided if possible.
#' 
#' There are cases where a real grouping item may appear superfluous, e.g. for a one-record dataset.  Enforce the groups by setting \code{simplify} to FALSE. 
#' 
#' The folded format supports mixed object types, as inferred from differences in relevant grouping items on a per record basis.  Mixed typing works best when object types form a nested hierarchy, i.e. all keys are left-subsets of the full key. Thus the order of grouping values is considered informative, e.g. for sorting.

#' @param x data.frame
#' @param ... unquoted names of grouping columns. See also \code{\link{fold.grouped_df}}.  Alternatively, pre-specify as a groups attribute (character vector).
#' @param meta a list of formulas in the form object ~ attribute. Pass something with length 0 to suppress guessing.
#' @param simplify set to NA any groups values that do not help distinguish values, and remove resulting duplicate records
#' @param sort whether to sort the result
#' @param tol maximum number of categories for guessing whether to encode metadata; encoding will always be attempted if metadata (attr) or its referent (obj) is a factor
#' @return folded data.frame with columns VARIABLE, META, VALUE and any supplied grouping items.
#' @seealso 
#' \code{\link{obj_attr.data.frame}}  
#' \code{\link{fold}} 
#' \code{\link{print.folded}} 
#' \code{\link{simplify.folded}} 
#' \code{\link{sort.folded}} 
#' \code{\link{unfold.folded}}
#' @importFrom lazyeval f_lhs
#' @importFrom lazyeval f_rhs
#' @importFrom tidyr spread
#' @importFrom tidyr gather
#' @export
#' @examples 
#' library(magrittr)
#' library(dplyr)
#' data(events)
#' x <- events
#' x %<>% filter(CMT == 2) %>% select(-EVID,-CMT,-AMT)
#' x %>% fold(USUBJID,TIME)
#' x %>% fold(USUBJID,TIME, meta = list(DV ~ BLQ, DV ~ LLOQ))
#' x <- events %>% 
#'   filter(CMT == 2) %>% 
#'   select(ID, TIME, TAD, DV, BLQ, LLOQ, SEX) 
#' x
#' attr(x,'groups') <- c('ID','TIME')
#' 
#' # less than 10 values of DV, so BLQ looks like an encoding
#' y <- x  %>% fold(meta=list(DV~BLQ,BLQ~LLOQ))
#' y %>% data.frame
#' 
#' # reducing the tolerance forces BLQ to match by groups (ID, TIME) instead of DV value
#' z <- x %>% fold(meta=list(DV~BLQ,BLQ~LLOQ),tol=3)
#' z
#' 
#' # another example
#' x <- Theoph
#' x %<>% mutate(
#'   conc_LABEL = 'theophylline concentration',
#'   conc_GUIDE = 'mg/L',
#'   Time_LABEL = 'time since drug administration',
#'   Time_GUIDE = 'hr',
#'   Time_HALF = Time / 2 # to demonstrate variant attribute of key column
#' )
#' x %<>% fold(Subject, Time)
#' x %>% unfold %>% head

#' \dontshow{
#' x <- events
#' x %<>% filter(CMT == 2) %>% select(-EVID,-CMT,-AMT)
#' attr(x,'groups') <- c('USUBJID','TIME')
#' y <- x %>% select(C, ID, TIME:PRED,USUBJID)
#' stopifnot(identical(fold(x),fold(y)))
#' }
fold.data.frame <- function(
  x,
  ...,
  meta = obj_attr(x),
  simplify = TRUE,
  sort = TRUE,
  tol = 10
){
  args <- quos(...)
  args <- lapply(args, f_rhs)
  grps <-   args[names(args) == '']
  other  <- args[names(args) != '']
  grps <- sapply(grps, as.character)
  if(length(grps) == 0)   grps <- c(character(0),attr(x,'groups'))
  do.call(
    fold_data_frame,
    c(
      list(
        x = x,
        groups = grps,
        meta = meta,
        simplify = simplify,
        sort = sort,
        tol = tol
      ),
      other # already a list
    )
  )
}


fold_data_frame <- function(
  x,
  groups = c(character(0),attr(x,'groups')),
  meta = obj_attr(x),
  simplify = TRUE,
  sort = TRUE,
  tol = 10,
  ...
){
  if(length(groups) == 0){
    message('Groups not specified.')
    if('ROW' %in% names(x)){
      message('ROW exists, not making default groups. Do you need to supply groups?')
    }else{
      message('using rownames as groups')
      x$ROW <- rownames(x)
      groups <- 'ROW'
    }
  }
  if(length(groups)){
    # we have groups, and order is important.
    # make sure the groups appear in order
    x <- x[, c(groups, setdiff(names(x),groups)),drop=FALSE]
  }
  # meta
  if(length(meta))
    if(is.null(names(meta)))
      names(meta) <- as.character(sapply(meta, f_rhs))
  table <- data.frame(
    stringsAsFactors = FALSE,
    VARIABLE = as.character(sapply(meta, f_lhs)),
    META     = as.character(sapply(meta, f_rhs)),
    COL = names(meta)
  )
  # data
  d <- x[,setdiff(names(x),table$COL),drop = FALSE]
  d <- tidyr::gather(d,VARIABLE,VALUE,UQS(syms(setdiff(names(d),groups))))
  d <- mutate(d,META = NA_character_)
  d <- mutate(d,VALUE = as.character(VALUE))
  #d <- as.folded(d, sort = sort, ...) # takes too long
  if(simplify) d <- simplify.folded(d,...) # d is data.frame
  if(nrow(table)){
    m <- getMeta(
      x = x,
      table = table, 
      groups = groups, 
      simplify = simplify, 
      tol = tol, 
      ...
    )
    d <- bind_rows(m,d)
  }
  #d <- ungroup(d)
  #class(d) <- c('folded','data.frame')
  #if(sort) d <- sort(d)
  d <- as.folded.data.frame(d, sort = sort, ...)
  d
}

#' Infer Object-Attribute Relationships
#' 
#' Infers object-attribute relationships.
#' @param x character
#' @param ... passed arguments
#' @export
#' @keywords internal
#' @seealso \code{\link{fold.data.frame}} \code{\link{obj_attr.character}} \code{\link{obj_attr.data.frame}}
obj_attr <- function(x,...)UseMethod('obj_attr')

#' Infer Object Attribute Relationships from Character
#' 
#' Infers object ~ attribute relationships from character.
#' 
#' Character is, for example, the names of a data.frame.  Processes the names, splitting on underscore and converting to formulas, with names same as the values in x that contained any underscores.
#' @inheritParams obj_attr
#' @return a named list of formulas in the form object ~ attribute
#' @export
#' @keywords internal
#' @importFrom stats as.formula
#' @seealso \code{\link{obj_attr}}
obj_attr.character <- function(x,...){
  x <- x[grepl( '_.',x)]
  y <- strsplit(x,'_') # all these should have two elements
  z <- lapply(y,paste,collapse = '~')
  z <- lapply(z,as.formula)
  names(z) <- x
  z
}

#' Infer Object Attribute Relationships from Data Frame
#' 
#' Infers object ~ attribute relationships from data.frame.  Processes the names of a data.frame.
#' @inheritParams obj_attr
#' @return a list of formulas in the form object ~ attribute
#' @import encode
#' @keywords internal
#' @export
#' @seealso \code{\link{obj_attr}} \code{\link{obj_attr.character}}
obj_attr.data.frame <- function(x,...)obj_attr(names(x),...)

#' Print Folded
#' 
#' Prints folded. Specifically, shortens display of encoded items that are above limit.
#' @param x folded
#' @param limit number of characters to allow without intervention
#' @param ... passed arguments
#' @export
#' @keywords internal
#' @return character
#' @seealso \code{\link{fold.data.frame}}
print.folded <- function(x, limit = 8, n = 10, ...){
  len <- nrow(x)
  n <- min(n,nrow(x),na.rm = TRUE)
  x <- x[seq_len(n),]
  x[] <- lapply(x,shortOrNot, limit = limit,  ...)
  cat('showing ', n, ' of ',len,' records\n')
  NextMethod()
}

#' Simplify Something
#' 
#' Simplifies something.
#' 
#' @param x object
#' @param ... passed arguments
#' @export
#' @seealso \code{\link{simplify.folded}}
simplify <- function(x,...)UseMethod('simplify')

#' Simplify Folded
#' 
#' Simplify folded. Per each combination of VARIABLE and META, find the minimum left subset of remaining columns necessary for uniquely distinguishing VALUE, setting other columns to NA. Then drop columns that are completely NA and remove duplicate records.
#'
#' @param x folded
#' @param ... passed arguments
#' @export
#' @return folded data.frame
#' @seealso \code{\link{simplify}}
#' @examples 
#' library(magrittr)
#' library(dplyr)
#' data(events)
#' x <- events
#' x %<>% filter(CMT == 2) %>% select(-EVID,-CMT,-AMT)
#' x %>% fold(USUBJID,TIME, meta = list(DV ~ BLQ, DV ~ LLOQ), simplify = FALSE) %>% simplify
simplify.folded <- function(x,...){
  key <- c('VARIABLE','META')
  modifiers <- setdiff(names(x),c('VARIABLE','META','VALUE'))
  for(col in modifiers){
    x$.key <- do.call(paste,c(x[key],list(sep = '\r')))
    x <- group_by(x,.key)
    x <- mutate(x, .n = length(unique(VALUE)))
    x <- group_by(x, VARIABLE,META)
    x <- mutate(x, .satisfied = all(.n == 1))
    x[[col]][x$.satisfied] <- NA
    key <- c(key,col)
  }
  if(length(modifiers)) x <- select(x, -.key,-.n,-.satisfied)
  if(length(modifiers)) x <-  ungroup(x)
  for(col in modifiers)if(all(is.na(x[[col]])))x[col] <- NULL
  x <- distinct(x, .keep_all = TRUE)
  class(x) <- c('folded','data.frame')
  x
}

is.defined <- function(x,...)!is.na(x)

map <- function (x, from, to, strict = TRUE, ...){
  stopifnot(length(to) == length(from))
  res <- to[match(x, table = from)]
  if (!strict) 
    res[!(x %in% from)] <- x[!(x %in% from)]
  res
}

unique.folded <- function(x, incomparables = FALSE,...){
  y <- unique.data.frame(x)
  class(y) <- union('folded',class(y))
  y
}

metaMerge <- function(x,...)UseMethod('metaMerge')

metaMerge.list <- function(x,all = TRUE,...){
  if(length(x) == 0)return(x)
  if(length(x) == 1)return(x[[1]])
  metaMerge(x = metaMerge(x[-length(x)]),y = x[[length(x)]],all = all,...)
}

metaMerge.character <- function(x,import = read.table,all = TRUE,...){
  miss <- x[!file.exists(x)]
  if(length(miss))stop('cannot find, e.g.,',miss[[1]])
  import <- match.fun(import)
  x <- lapply(x,import,...)
  metaMerge(x,all = all,...)
}

metaMerge.default <- function(x,y,all = TRUE,...)merge(x,y,all = all,...)

metaMerge.data.frame <- function(x,y,all = TRUE, sort = FALSE, ...){
  if(is.null(y))warning('merging data.frame with NULL object')
  # Here we deliberately disable all sorting.
  # Sort is trapped in the formals but over-ridden as FALSE.
  # Sort scheme is relegated to unfold.folded.
  # Per help, merge.data.frame sorts lexically only: inadequate for our purposes.
  merge(x,y,all = all, sort = FALSE, ...)
}

metaMerge.NULL <- function(x,y,all = TRUE,...){
  warning('merging NULL object')
  merge(x,y,all = all,...)
}

.informative <- function (x, ...){
  x[, sapply(x, function(col) any(!is.na(col))), drop = FALSE]
}

getMeta <- function(x, table, groups, simplify, tol, ...){
  # prevent tidyr warning about differing attributes.  
  # Factor levels to be recovered later from x.
  m <- x
  fac <- sapply(x,is.factor)
  m[fac] <- lapply(m[fac],as.character)
  m <-  dplyr::select(m, UQS(syms(c(groups,table$COL))))
  m <-  tidyr::gather(m, COL, VALUE, UQS(syms(table$COL)))
  m <-  unique(m)
  m <- left_join(m,table,by = 'COL') 
  #m <- dplyr::select(m, -COL)
  m <- dplyr::select(m, VARIABLE, META, VALUE, COL, UQS(syms(groups)))
  # m <- as.folded(m, sort = sort, ...)
  table$encoding <- sapply(seq_len(nrow(table)), supplyEncoding,source = x,table = table, tol = tol, ...)
  m <- left_join(m, select(table, VARIABLE, META, encoding),by = c('VARIABLE','META'))
  m$VALUE[!is.na(m$encoding)] <- m$encoding[!is.na(m$encoding)]
  m$encoding <- NULL
  m$COL <- NULL
  m <- unique(m) # remove copies of encodings, if any
  if(simplify) m <- simplify.folded(m,...)
  # supplyEncoding does not work for keys
  for(i in groups){
    if(i %in% names(m) & is.factor(x[[i]])) {
      m[[i]] <- factor(
        m[[i]], 
        levels = levels(x[[i]]), 
        ordered = is.ordered(x[[i]])
      )
    }
  }
  m
}

mapped <- function(x,y){ # TRUE if there is only one y for each x
  length(unique(x)) == length(unique(paste(x,y,sep = '\r')))
}

encodeable <- function(x,y, tol = 10,...){
  mapped <- mapped(x,y)
  xfactor <- is.factor(x)
  yfactor <- is.factor(y)
  len <- length(unique(x))
  if( (xfactor || yfactor) & mapped ) return(TRUE)
  if(mapped & len <= tol & length(unique(y)) > 1) return(TRUE)
  FALSE
}

encoding <- function(x,y, ...){
  data <- data.frame(x = x, y = y)
  if(is.factor(y)) data <- arrange(data, y)
  if(is.factor(x)) data <- arrange(data, x)
  data <- unique(data) # one y for each x (by definition), so first suffices
  # codes <- if(is.factor(x)) levels(x) else unique(as.character(x))
  # decodes <- y[match(codes,x)] 
  encoding <- encode(paste(data$x),data$y) # must trap NA codes
  encoding
}

supplyEncoding <- function(i,table, source, tol, ...){
  var <- table[i,'VARIABLE']
  met <- table[i,'META']
  col <- table[i,'COL']
  c <- source[[col]]
  v <- source[[var]]
  if(encodeable(v,c, tol = tol, ...))encoding(v,c) else NA_character_
}

shortOrNot <- function(x, limit = 8, ...){ # n = 10
  if(!is.character(x)) return(x)
  test <- x # x[seq_len(n)]
  chars <- nchar(test)
  chars[is.na(chars)] <- 0
  enc <- encoded(test)
  issues <- enc & chars > limit
  #  if(any(issues)) x[seq_len(n)] <- short(x[seq_len(n)], n = limit)
  if(any(issues)) x <- short(x, n = limit)
  return(x)
}

short <- function(x, n = 8 ){
  y <- substr(x,1, n)
  nchar <- nchar(x)
  y <- paste0(y,ifelse(nchar > n,'...',''))
  y <- as.character(y)
  y[is.na(x)] <- NA_character_
  y
}

weld <- function(x,y,...){
  stopifnot(
    inherits(x,'data.frame'),
    inherits(y,'data.frame')
  )
  if(!nrow(x) & !nrow(y))return(x)
  if(!nrow(x) &  nrow(y))return(y)
  if( nrow(x) & !nrow(y))return(x)
  if( nrow(x) &  nrow(y))merge(x,y,all = T, sort = FALSE)
}

decode.data.frame <- function(
  x, 
  encoded, 
  encoding,
  decoded,
  ...
){
  stopifnot(length(encoding) == 1)
  if(!encoded %in% names(x))return(x)
  if(decoded %in% names(x)){
    warning(decoded,' already present, skipping decode ')
    return(x)
  }
  #if(length(unique(x[[encoding]])) > 1)warning(encoding, 'unsing only the first value of ',encoding)
  #enc <- x[1,encoding]
  if(!encoded(encoding)){
    warning(encoding, ' appears not to be encoded, no decode attempted')
    return(x)
  }
  codes <- codes(encoding)
  decodes <- decodes(encoding)
  codes[codes == 'NA'] <- NA_character_
  decodes[decodes == 'NA'] <- NA_character_
  x[[decoded]] <- map(x[[encoded]], from = codes, to = decodes)
  x[[decoded]] <- factor(x[[decoded]],levels = unique(decodes))
  #x[[encoded]] <- factor(x[[encoded]],levels = codes)
  x
}

#' Coerce to Folded from Spec
#' Coerces to folded from spec.  Harvests column names, labels and units.  Stacks these in conventional folded format.
#' 
#' @param x spec
#' @param ... passed arguments
#' @return folded
#' @import spec
#' @export
as.folded.spec <- function(x,...){
  y <- x
  y <- mutate(y, guide = ifelse(encoded(x), guide, guidetext(x)))
  y <- select(y, VARIABLE = column, LABEL = label, GUIDE = guide)
  y <- tidyr::gather(y, META, VALUE, LABEL, GUIDE)
  class(y) <- 'data.frame'
  y <- as.folded(y)
  y
}

#' Coerce to Folded from Definitions
#' Coerces to folded from definitions  Harvests item, label, and unit for tabled items.  Stacks these in conventional folded format.
#' 
#' @param x definitions
#' @param parameters whether to included parameter metadata
#' @param ... passed arguments
#' @return folded
#' @export
as.folded.definitions <- function(x, parameters = FALSE, ...){
  y <- select(x,VARIABLE = item, LABEL = label, GUIDE = unit)
  if(!parameters) y <- filter(y, !grepl('theta_|omega_|sigma_',VARIABLE))
  y <- tidyr::gather(y, META, VALUE, LABEL, GUIDE)
  class(y) <- 'data.frame'
  y <- as.folded(y)
  y
}
globalVariables('item')
globalVariables('label')
globalVariables('unit')
globalVariables('column')
globalVariables('label')
globalVariables('guide')
globalVariables('VALUE')
globalVariables('LABEL')
globalVariables('GUIDE')
globalVariables('META')
globalVariables('COL')
globalVariables('VARIABLE')
globalVariables('.key')
globalVariables('.n')
globalVariables('.satisfied')
globalVariables('read.table')


