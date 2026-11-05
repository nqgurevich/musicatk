library(musicatk)

# Flanks of the pyrimidine-strand base, computed independently: take the
# + strand window around each SBS, reverse-complement it for purine refs,
# then read bases from the pyrimidine strand's 5' or 3' side.
.pyrimidine_flank <- function(v, g, flank_start, flank_end) {
  width <- max(abs(flank_start), abs(flank_end))
  window <- VariantAnnotation::getSeq(g, v$chr, v$start - width,
    v$start + width,
    as.character = TRUE
  )
  purine <- v$ref %in% c("A", "G")
  window[purine] <- as.character(Biostrings::reverseComplement(
    Biostrings::DNAStringSet(window[purine])
  ))
  unname(substr(window, width + 1 + flank_start, width + 1 + flank_end))
}

test_that("add_flank_to_variants reads 5' flanks on the pyrimidine strand", {
  data(musica)
  g <- select_genome("hg38")
  m <- musica
  add_flank_to_variants(m, g, -2, -1, build_table = FALSE)
  v <- variants(m)

  # G>T at chr1:43430030; + strand CAGTC, pyrimidine strand GACTG
  i <- which(v$chr == "chr1" & v$start == 43430030)
  expect_identical(v$lflank_2_to_1[i], "GA")

  sbs <- v$Variant_Type == "SBS"
  expect_identical(
    unname(v$lflank_2_to_1[sbs]),
    .pyrimidine_flank(v[sbs, ], g, -2, -1)
  )
})

test_that("add_flank_to_variants reads 3' flanks on the pyrimidine strand", {
  data(musica)
  g <- select_genome("hg38")
  m <- musica
  add_flank_to_variants(m, g, 1, 2, build_table = FALSE)
  v <- variants(m)

  i <- which(v$chr == "chr1" & v$start == 43430030)
  expect_identical(v$rflank_1_to_2[i], "TG")

  sbs <- v$Variant_Type == "SBS"
  expect_identical(
    unname(v$rflank_1_to_2[sbs]),
    .pyrimidine_flank(v[sbs, ], g, 1, 2)
  )
})

test_that("add_flank_to_variants handles input with one reference class", {
  data(musica)
  g <- select_genome("hg38")
  v <- variants(musica)
  for (refs in list(c("C", "T"), c("A", "G"))) {
    m <- musica
    variants(m) <- v[v$ref %in% refs, ]
    add_flank_to_variants(m, g, -2, -1, build_table = FALSE)
    w <- variants(m)
    sbs <- w$Variant_Type == "SBS"
    expect_identical(
      unname(w$lflank_2_to_1[sbs]),
      .pyrimidine_flank(w[sbs, ], g, -2, -1)
    )
  }
})

test_that("add_flank_to_variants counts corrected flanks in its table", {
  data(musica)
  g <- select_genome("hg38")
  m <- musica
  add_flank_to_variants(m, g, -2, -1)
  counts <- get_count_table(tables(m)$lflank_2_to_1)

  v <- variants(musica)
  sbs <- v$Variant_Type == "SBS"
  flank <- .pyrimidine_flank(v[sbs, ], g, -2, -1)
  expected <- table(
    factor(flank, levels = rownames(counts)),
    factor(v$sample[sbs], levels = colnames(counts))
  )
  expect_equal(unname(counts), unname(unclass(expected)),
    ignore_attr = TRUE
  )
})
