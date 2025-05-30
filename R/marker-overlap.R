# JSI calculation
# we define JSI of 2 empty sets as 0
jaccard_index <- function(a,
                          b) {
    if ((length(a) == 0) & (length(b) == 0)) {
        return(0)
    } else {
        union.size <- length(union(a, b))
        intersect.size <- length(intersect(a, b))
        return(intersect.size / union.size)
    }
}

#' Cell-Wise Marker Gene Overlap
#'
#' @description Calculates the per-cell overlap of previously calculated
#' marker genes.
#'
#' @param markers1 The first data frame of marker genes, must contain columns
#' called 'gene' and 'cluster'.
#' @param markers2 The second data frame of marker genes, must contain columns
#' called 'gene' and 'cluster'.
#' @param clustering1 The first vector of cluster assignments.
#' @param clustering2 The second vector of cluster assignments.
#' @param n The number of top n markers (ranked by rank_by) to use when
#' calculating the overlap.
#' @param overlap_type The type of overlap to calculated: must be one of 'jsi'
#' for Jaccard similarity index and 'intersect' for intersect size.
#' @param rank_by A character string giving the name of the column to rank
#' marker genes by. Note the sign here: to rank by lowest p-value, preface
#' the column name with a minus sign; to rank by highest value, where higher
#' value indicates more discriminative genes (for example power in the ROC
#' test), no sign is needed.
#' @param use_sign A logical: should the sign of markers match for overlap
#' calculations? So a gene must be a positive or a negative marker in both
#' clusters being compared. If TRUE, markers1 and markers2 must have a
#' 'avg_logFC' or 'avg_log2FC' column, from which the sign of the DE will be
#' extracted.
#'
#'
#' @return A vector of the marker gene overlap per cell.
#' @export
#'
#' @examples
#' suppressWarnings({
#'     set.seed(1234)
#'     library(Seurat)
#'     data("pbmc_small")
#'
#'     # cluster with Louvain algorithm
#'     pbmc_small <- FindClusters(pbmc_small, resolution = 0.8, verbose = FALSE)
#'
#'     # cluster with k-means
#'     pbmc.pca <- Embeddings(pbmc_small, "pca")
#'     pbmc_small@meta.data$kmeans_clusters <- kmeans(pbmc.pca, centers = 3)$cluster
#'
#'     # compare the markers
#'     Idents(pbmc_small) <- pbmc_small@meta.data$seurat_clusters
#'     louvain.markers <- FindAllMarkers(pbmc_small,
#'         logfc.threshold = 1,
#'         test.use = "t",
#'         verbose = FALSE
#'     )
#'
#'     Idents(pbmc_small) <- pbmc_small@meta.data$kmeans_clusters
#'     kmeans.markers <- FindAllMarkers(pbmc_small,
#'         logfc.threshold = 1,
#'         test.use = "t",
#'         verbose = FALSE
#'     )
#'
#'     pbmc_small@meta.data$jsi <- marker_overlap(
#'         louvain.markers, kmeans.markers,
#'         pbmc_small@meta.data$seurat_clusters, pbmc_small@meta.data$kmeans_clusters
#'     )
#'
#'     # which cells have the same markers, regardless of clustering?
#'     FeaturePlot(pbmc_small, "jsi")
#' })
marker_overlap <- function(markers1,
                           markers2,
                           clustering1,
                           clustering2,
                           n = 25,
                           overlap_type = "jsi",
                           rank_by = "-p_val",
                           use_sign = TRUE) {
    overlap.vals <- rep(0, length(clustering1))
    names(overlap.vals) <- names(clustering1)

    # extract top n markers
    markers1 <- markers1 %>%
        dplyr::group_by(.data$cluster) %>%
        dplyr::slice_max(n = n, order_by = eval(parse(text = rank_by)))
    markers2 <- markers2 %>%
        dplyr::group_by(.data$cluster) %>%
        dplyr::slice_max(n = n, order_by = eval(parse(text = rank_by)))

    # if use_sign is TRUE, we append the sign to the gene name, so it will be used
    # during overlap calculations
    if (use_sign) {
        append_sign <- function(x) if (x > 0) "+" else if (x < 0) "-" else "0"
        if ("avg_logFC" %in% intersect(
            colnames(markers1),
            colnames(markers2)
        )) {
            markers1$gene <- paste0(
                markers1$gene,
                sapply(markers1$avg_logFC, append_sign)
            )
            markers2$gene <- paste0(
                markers2$gene,
                sapply(markers2$avg_logFC, append_sign)
            )
        } else if ("avg_log2FC" %in% intersect(
            colnames(markers1),
            colnames(markers2)
        )) {
            markers1$gene <- paste0(
                markers1$gene,
                sapply(markers1$avg_log2FC, append_sign)
            )
            markers2$gene <- paste0(
                markers2$gene,
                sapply(markers2$avg_log2FC, append_sign)
            )
        } else {
            stop("If use_sign is TRUE, the marker tables must contain a column with
           name avg_logFC or avg_log2FC.")
        }
    }

    # compare every cluster in clustering1 with every cluster in clustering2
    for (c1 in unique(clustering1)) {
        cells.in.c1 <- (clustering1 == c1)
        discr1 <- markers1 %>%
            dplyr::filter(.data$cluster == c1) %>%
            dplyr::pull(.data$gene)
        for (c2 in unique(clustering2)) {
            cells.in.c2 <- (clustering2 == c2)
            discr2 <- markers2 %>%
                dplyr::filter(.data$cluster == c2) %>%
                dplyr::pull(.data$gene)
            cells.in.both <- cells.in.c1 & cells.in.c2
            if (any(cells.in.both)) {
                if (overlap_type == "jsi") {
                    overlap.vals[cells.in.both] <- jaccard_index(discr1, discr2)
                } else if (overlap_type == "intersect") {
                    overlap.vals[cells.in.both] <- length(intersect(discr1, discr2))
                }
            }
        }
    }

    return(overlap.vals)
}
