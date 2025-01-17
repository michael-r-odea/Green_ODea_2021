# This is the code used for the analysis comparing Mrc1+ microglia to Mrc1- microglia in LPC injected mice in the Hammond et al. 2019 single-cell RNA-sequencing data
# note: file paths apply to local system and may change

library(Seurat)
library(dplyr)

setwd("./input_data_files/LPC/")
data.files <- list.files()
hammond.data <- lapply(data.files, read.table, header = TRUE, row.names = 1, sep = "\t")

names(hammond.data) <- stringr::str_replace(data.files, pattern = ".dge.txt", replacement = "")
hammond.names.1 <- names(hammond.data)
names(hammond.data) <- stringr::str_replace(hammond.names.1, pattern = "GSM......._", replacement = "")
hammond.object.names <- names(hammond.data)

# Initialize the Seurat object with the raw (non-normalized) data.
hammond.data.s <- lapply(hammond.data, CreateSeuratObject, project = "Hammond")

# Calculates the percentage of mitochondrial genes here and store it in percent.mt  

for (i in seq_along(hammond.data.s)){
  hammond.data.s[[i]]@meta.data[["percent.mt"]] <- PercentageFeatureSet(object = hammond.data.s[[i]], pattern = "^mt.")
}

hammond.data.s <- lapply(hammond.data.s, subset, subset = nFeature_RNA > 400 & nFeature_RNA < 3000 & nCount_RNA < 10000 & percent.mt < 3)

lpc <- merge(hammond.data.s[[1]], y = c(hammond.data.s[[2]],
                                        hammond.data.s[[3]]),
             add.cell.ids = c("LPC1", "LPC2", "LPC3"),
             project = "hammond_lpc")

lpc <- NormalizeData(lpc, normalization.method = "LogNormalize", scale.factor = 10000)
lpc <- FindVariableFeatures(lpc, selection.method = "vst", nfeatures = 2000)

mrc1_lpc <- WhichCells(lpc, expression = Mrc1 > 0) # split cells into mrc1+ and mrc1-
other_lpc <- WhichCells(lpc, expression = Mrc1 == 0)

lpc <- SetIdent(object = lpc, cells = mrc1_lpc, value = 'Mrc1+')
lpc <- SetIdent(object = lpc, cells = other_lpc, value = 'Mrc1-')

microglia.features <- c("Tmem119", "P2ry12", "Lcp1", "Cx3cr1", "Irf8", "Sall1", "Mpeg1", "Csf1r", "Mrc1") 

mrc1.microglia.markers <- FindMarkers(lpc, ident.1 = "Mrc1+", ident.2 = "Mrc1-", features = microglia.features, # test canonical microglia marker expression
                                      min.cells.group = 1, 
                                      min.cells.feature = 1,
                                      min.pct = 0,
                                      logfc.threshold = 0,
                                      only.pos = FALSE, return.thresh = 1)
saveRDS(mrc1.microglia.markers, "mrc1_pos_neg_marks.rds")
write.csv(mrc1.microglia.markers, "mrc1_pos_neg_marks.csv")

#### adding chart for expression tests
# Render a bar chart with positive and negative values
bar_chart_pos_neg <- function(label, value, max_value = 2.00, height = "16px",
                              pos_fill = "#02aa5c", neg_fill = "#ff121a") {
  neg_chart <- div(style = list(flex = "1 1 0"))
  pos_chart <- div(style = list(flex = "1 1 0"))
  width <- paste0(abs(value / max_value) * 100, "%")
  
  if (value < 0) {
    bar <- div(style = list(marginLeft = "8px", background = neg_fill, width = width, height = height))
    chart <- div(style = list(display = "flex", alignItems = "center", justifyContent = "flex-end"), label, bar)
    neg_chart <- tagAppendChild(neg_chart, chart)
  } else {
    bar <- div(style = list(marginRight = "8px", background = pos_fill, width = width, height = height))
    chart <- div(style = list(display = "flex", alignItems = "center"), bar, label)
    pos_chart <- tagAppendChild(pos_chart, chart)
  }
  
  div(style = list(display = "flex"), neg_chart, pos_chart)
}

mrc1.microglia.markers <- mrc1.microglia.markers %>% select(-1)
reactable(mrc1.microglia.markers, columns = list(avg_log2FC = colDef(name = "Log Fold Change", format = colFormat(digits = 4), 
                                                                     cell = function(value) {
                                                                       label <- round(value, digits = 2)
                                                                       bar_chart_pos_neg(label, value)
                                                                     },
                                                                     align = "center",
                                                                     minWidth = 150), 
                                                 pct.1 = colDef(name = "Mrc1+ cells with expression", format = colFormat(percent = TRUE, digits = 1)), 
                                                 pct.2 = colDef(name = "Mrc1- cells with expression", format = colFormat(percent = TRUE, digits = 1)), 
                                                 p_val_adj = colDef(name = "Mann-Whitney U Test", cell = function(value) {
                                                   if (value == 1) {
                                                     paste0("p = ", value)
                                                   } else {
                                                     paste0("p < ", signif(value, digits = 2))
                                                   }}, format = colFormat(digits = 5), 
                                                   style = function(value) {
                                                     if (value <= 0.05) {
                                                       color <- "#008000"
                                                     } else {
                                                       color <- "#e00000"
                                                     }
                                                     list(color = color, fontWeight = "bold")
                                                   })), 
          compact = TRUE,
          resizable = TRUE, 
          bordered = TRUE, 
          fullWidth = FALSE, 
          rowStyle = function(index){
            if(index == 1) list(background = "rgba(0, 0, 0, 0.05)")
          })


#exporting lpc data to scanpy anndata format; will be opened in python ("vlnplots.py"), and stacked violin plot is generated. 
lpc$cell_ident <- Idents(lpc)

sceasy::convertFormat(lpc, from="seurat", to="anndata",outFile='hammond_lpc.h5ad')


# Comparison of LPC Mrc1+ expression to Saline controls:

# NOTE: organize all data files into a subfolder in the working directory; then switch the working directory to the subfolder and run the next line 
# Read DGE files; dge.txt files can be downloaded from the NCBI GEO website (GSE121654); this segment of code uses all the originanl dge files from all samples
data.files <- list.files()
hammond.data <- lapply(data.files, read.table, header = TRUE, row.names = 1, sep = "\t")

names(hammond.data) <- stringr::str_replace(data.files, pattern = ".dge.txt", replacement = "")
hammond.names.1 <- names(hammond.data)
names(hammond.data) <- stringr::str_replace(hammond.names.1, pattern = "GSM......._", replacement = "")
hammond.object.names <- names(hammond.data)

# Initialize the Seurat object with the raw (non-normalized) data.
hammond.data.s <- lapply(hammond.data, CreateSeuratObject, project = "Hammond")

# Calculates the percentage of mitochondrial genes here and store it in percent.mt  

for (i in seq_along(hammond.data.s)){
  hammond.data.s[[i]]@meta.data[["percent.mt"]] <- PercentageFeatureSet(object = hammond.data.s[[i]], pattern = "^mt.")
}

# visualize QC metrics for each object
pdf(paste("hammond2_QCplots.pdf", sep=""))
for (i in seq_along(hammond.data.s)){
  txt <- hammond.object.names[[i]]
  plot.new()
  text(.5, .5, txt, font=2, cex=1.5)
  print(VlnPlot(hammond.data.s[[i]], features = c("nFeature_RNA", "nCount_RNA", "percent.mt"), ncol = 3))
  print(FeatureScatter(object = hammond.data.s[[i]], feature1 = "nCount_RNA", feature2 = "nFeature_RNA"))
  print(FeatureScatter(object = hammond.data.s[[i]], feature1 = "nCount_RNA", feature2 = "percent.mt"))
}
dev.off()

# based on QC plots, filtering out cells with <400 genes or > 3000 unique genes; cells with > 10,000 UMIs, and cells with greater than 3% of reads mapping to mitochondrial genes 
hammond.data.filtered <- lapply(hammond.data.s, subset, subset = nFeature_RNA > 400 & nFeature_RNA < 3000 & nCount_RNA < 10000 & percent.mt < 3)

# next, output a dataframe with the cell counts of each sample before and after QC filtering 
unfilt <- c()
filt <- c()
for(i in seq_along(hammond.data.s)){
  hammond.object.names[[i]]
  unfilt <- c(unfilt, ncol(hammond.data.s[[i]]))
  filt <- c(filt, ncol(hammond.data.filtered[[i]]))
}
combo <- c(unfilt, filt)
QC.cell.nums <- matrix(combo, nrow = 47, ncol = 2)
rownames(QC.cell.nums) <- c(hammond.object.names)
colnames(QC.cell.nums) <- c("Pre-QC Filtering", "Post-QC Filtering")

saveRDS(hammond.data.filtered, "hammond_list_filtered.rds") # save filtered list for later


hammond.list <- readRDS("hammond_list_filtered.rds") # read data
hammond.merged <- merge(hammond.list[[1]], y = c(hammond.list[[2]], hammond.list[[3]], hammond.list[[4]], 
                                                 hammond.list[[5]],
                                                 hammond.list[[6]],
                                                 hammond.list[[7]],
                                                 hammond.list[[8]],
                                                 hammond.list[[9]],
                                                 hammond.list[[10]],
                                                 hammond.list[[11]],
                                                 hammond.list[[12]],
                                                 hammond.list[[13]],
                                                 hammond.list[[14]],
                                                 hammond.list[[15]],
                                                 hammond.list[[16]],
                                                 hammond.list[[17]],
                                                 hammond.list[[18]],
                                                 hammond.list[[19]],
                                                 hammond.list[[20]],
                                                 hammond.list[[21]],
                                                 hammond.list[[22]],
                                                 hammond.list[[23]],
                                                 hammond.list[[24]],
                                                 hammond.list[[25]],
                                                 hammond.list[[26]],
                                                 hammond.list[[27]],
                                                 hammond.list[[28]],
                                                 hammond.list[[29]],
                                                 hammond.list[[30]],
                                                 hammond.list[[31]],
                                                 hammond.list[[32]],
                                                 hammond.list[[33]],
                                                 hammond.list[[34]],
                                                 hammond.list[[35]],
                                                 hammond.list[[36]],
                                                 hammond.list[[37]],
                                                 hammond.list[[38]],
                                                 hammond.list[[39]],
                                                 hammond.list[[40]],
                                                 hammond.list[[41]], 
                                                 hammond.list[[42]],
                                                 hammond.list[[43]],
                                                 hammond.list[[44]],
                                                 hammond.list[[45]],
                                                 hammond.list[[46]],
                                                 hammond.list[[47]]
),
add.cell.ids = c("E14", "E14", "E14","E14","E14","E14","E14","E14",
                 "P5", "P5",
                 "P4","P4","P4","P4","P4","P4",
                 "P30", "P30", "P30", "P30", 
                 "P100","P100", "P100","P100","P100","P100","P100","P100",
                 "P540", "P540", "P540", "P540",
                 "P100", "P100", "P100", 
                 "P100 control", "P100 control", "P100 control",
                 "P100 LPC", "P100 LPC","P100 LPC", 
                 "P5", "P5", "P5", "P5", "P5", "P5"),
project = "hammond_merge")


cells <- colnames(hammond.merged)
genes <- rownames(hammond.merged)
hammond.merged$sample <- gsub("_.*$","", cells) # add column for sample age


d1 <- hammond.list[[1]]@assays$RNA@counts["Mrc1",] # extract Mrc1 column from count matrix for each sample
d2 <- hammond.list[[2]]@assays$RNA@counts["Mrc1",]
d3 <- hammond.list[[3]]@assays$RNA@counts["Mrc1",]
d4 <- hammond.list[[4]]@assays$RNA@counts["Mrc1",]
d5 <- hammond.list[[5]]@assays$RNA@counts["Mrc1",]
d6 <- hammond.list[[6]]@assays$RNA@counts["Mrc1",]
d7 <- hammond.list[[7]]@assays$RNA@counts["Mrc1",]
d8 <- hammond.list[[8]]@assays$RNA@counts["Mrc1",]
d9 <- hammond.list[[9]]@assays$RNA@counts["Mrc1",]
d10 <- hammond.list[[10]]@assays$RNA@counts["Mrc1",]
d11 <- hammond.list[[11]]@assays$RNA@counts["Mrc1",]
d12 <- hammond.list[[12]]@assays$RNA@counts["Mrc1",]
d13 <- hammond.list[[13]]@assays$RNA@counts["Mrc1",]
d14 <- hammond.list[[14]]@assays$RNA@counts["Mrc1",]
d15 <- hammond.list[[15]]@assays$RNA@counts["Mrc1",]
d16 <- hammond.list[[16]]@assays$RNA@counts["Mrc1",]
d17 <- hammond.list[[17]]@assays$RNA@counts["Mrc1",]
d18 <- hammond.list[[18]]@assays$RNA@counts["Mrc1",]
d19 <- hammond.list[[19]]@assays$RNA@counts["Mrc1",]
d20 <- hammond.list[[20]]@assays$RNA@counts["Mrc1",]
d21 <- hammond.list[[21]]@assays$RNA@counts["Mrc1",]
d22 <- hammond.list[[22]]@assays$RNA@counts["Mrc1",]
d23 <- hammond.list[[23]]@assays$RNA@counts["Mrc1",]
d24 <- hammond.list[[24]]@assays$RNA@counts["Mrc1",]
d25 <- hammond.list[[25]]@assays$RNA@counts["Mrc1",]
d26 <- hammond.list[[26]]@assays$RNA@counts["Mrc1",]
d27 <- hammond.list[[27]]@assays$RNA@counts["Mrc1",]
d28 <- hammond.list[[28]]@assays$RNA@counts["Mrc1",]
d29 <- hammond.list[[29]]@assays$RNA@counts["Mrc1",]
d30 <- hammond.list[[30]]@assays$RNA@counts["Mrc1",]
d31 <- hammond.list[[31]]@assays$RNA@counts["Mrc1",]
d32 <- hammond.list[[32]]@assays$RNA@counts["Mrc1",]
d33 <- hammond.list[[33]]@assays$RNA@counts["Mrc1",]
d34 <- hammond.list[[34]]@assays$RNA@counts["Mrc1",]
d35 <- hammond.list[[35]]@assays$RNA@counts["Mrc1",]
d36 <- hammond.list[[36]]@assays$RNA@counts["Mrc1",]
d37 <- hammond.list[[37]]@assays$RNA@counts["Mrc1",]
d38 <- hammond.list[[38]]@assays$RNA@counts["Mrc1",]
d39 <- hammond.list[[39]]@assays$RNA@counts["Mrc1",]
d40 <- hammond.list[[40]]@assays$RNA@counts["Mrc1",]
d41 <- hammond.list[[41]]@assays$RNA@counts["Mrc1",]
d42 <- hammond.list[[42]]@assays$RNA@counts["Mrc1",]
d43 <- hammond.list[[43]]@assays$RNA@counts["Mrc1",]
d44 <- hammond.list[[44]]@assays$RNA@counts["Mrc1",]
d45 <- hammond.list[[45]]@assays$RNA@counts["Mrc1",]
d46 <- hammond.list[[46]]@assays$RNA@counts["Mrc1",]
d47 <- hammond.list[[47]]@assays$RNA@counts["Mrc1",]

umi_sums <- c(Reduce("+",d1),Reduce("+",d2), Reduce("+",d3),Reduce("+",d4),Reduce("+",d5),Reduce("+",d6),Reduce("+",d7),Reduce("+",d8),Reduce("+",d9),
              Reduce("+",d10),Reduce("+",d11),Reduce("+",d12),Reduce("+",d13),Reduce("+",d14),Reduce("+",d15),Reduce("+",d16),Reduce("+",d17),Reduce("+",d18),
              Reduce("+",d19),Reduce("+",d20),Reduce("+",d21),Reduce("+",d22),Reduce("+",d23),Reduce("+",d24),Reduce("+",d25),Reduce("+",d26),Reduce("+",d27),
              Reduce("+",d28),Reduce("+",d29),Reduce("+",d30),Reduce("+",d31),Reduce("+",d32),Reduce("+",d33),Reduce("+",d34),Reduce("+",d35),
              Reduce("+",d36),Reduce("+",d37),Reduce("+",d38),Reduce("+",d39),Reduce("+",d40),Reduce("+",d41), Reduce("+",d42), Reduce("+",d43), Reduce("+",d44),
              Reduce("+",d45), Reduce("+",d46),Reduce("+",d47)) # calculate sum of mrc1 umis in each sample

idents <- c("E14", "E14", "E14","E14","E14","E14","E14","E14",
            "P4/5", "P4/5",
            "P4/5","P4/5","P4/5","P4/5","P4/5","P4/5",
            "P30", "P30", "P30", "P30", 
            "P100","P100", "P100","P100","P100","P100","P100","P100",
            "P540", "P540", "P540", "P540", 
            "P100", "P100", "P100",
            "P100 control", "P100 control", "P100 control", 
            "P100 LPC", "P100 LPC", "P100 LPC", 
            "P4/5", "P4/5", "P4/5", "P4/5", "P4/5", "P4/5")

cell_no <- c(length(d1),length(d2),length(d3),length(d4),length(d5),length(d6),length(d7),length(d8),length(d9),length(d10),length(d11),length(d12),length(d13),length(d14),length(d15),
             length(d16),length(d17),length(d18),length(d19),length(d20),length(d21),length(d22),length(d23),length(d24),length(d25),length(d26),length(d27),length(d28),
             length(d29),length(d30), length(d31),length(d32),length(d33),length(d34),length(d35),length(d36),length(d37),length(d38),length(d39),length(d40),length(d41),
             length(d42),length(d43),length(d44),length(d45),length(d46),length(d47)) # calculate total number of cells in each sample

mrc1_umis <- data.frame(umi_sums, idents, cell_no) # generate dataframe with mrc1 umi sums and cell number per sample

mrc1_umis[, "idents"] <- factor(mrc1_umis[, "idents"], levels = c("E14", "P4/5", "P30", "P100", "P540", "P100 control", "P100 LPC"), ordered = TRUE) # add idents column with sample age  
mrc1_umis <- mrc1_umis %>% mutate(umis_per_cell = umi_sums/cell_no) # calculate mrc1 average umi counts per cell

# LPC injury mrc1+ cells quantification
Idents(hammond.list[[36]]) <- "Control 1"
Idents(hammond.list[[37]]) <- "Control 2"
Idents(hammond.list[[38]]) <- "Control 3"
Idents(hammond.list[[39]]) <- "LPC 1"
Idents(hammond.list[[40]]) <- "LPC 2"
Idents(hammond.list[[41]]) <- "LPC 3"

hammond.lpc <- merge(hammond.list[[36]], y = c(hammond.list[[37]],
                                               hammond.list[[38]],
                                               hammond.list[[39]],
                                               hammond.list[[40]],
                                               hammond.list[[41]]),
                     add.cell.ids = c("control_1", "control_2", "control_3",
                                      "LPC_1", "LPC_2","LPC_3"),
                     project = "hammond_lpc")

hammond.lpc <- NormalizeData(hammond.lpc, normalization.method = "LogNormalize", scale.factor = 10000)
hammond.lpc <- FindVariableFeatures(hammond.lpc, selection.method = "vst", nfeatures = 2000)

VlnPlot(hammond.lpc, features = "Mrc1")

hammond.lpc.control1 <- subset(hammond.lpc, idents = "Control 1")
hammond.lpc.control1 # 1170 cells
length(WhichCells(hammond.lpc.control1, expression = Mrc1 > 0)) # 17 Mrc1+ cells


hammond.lpc.control2 <- subset(hammond.lpc, idents = "Control 2")
hammond.lpc.control2 # 1038 cells
length(WhichCells(hammond.lpc.control2, expression = Mrc1 > 0)) # 16 Mrc1+ cells

hammond.lpc.control3 <- subset(hammond.lpc, idents = "Control 3")
hammond.lpc.control3 # 415 cells
length(WhichCells(hammond.lpc.control3, expression = Mrc1 > 0)) # 3 Mrc1+ cells

hammond.lpc.1 <- subset(hammond.lpc, idents = "LPC 1")
hammond.lpc.1 # 1118 cells
length(WhichCells(hammond.lpc.1, expression = Mrc1 > 0)) # 31 Mrc1+ cells

hammond.lpc.2 <- subset(hammond.lpc, idents = "LPC 2")
hammond.lpc.2 # 1132 cells
length(WhichCells(hammond.lpc.2, expression = Mrc1 > 0)) # 67 Mrc1+ cells

hammond.lpc.3 <- subset(hammond.lpc, idents = "LPC 3")
hammond.lpc.3 # 472 cells
length(WhichCells(hammond.lpc.3, expression = Mrc1 > 0)) # 26 Mrc1+ cells

# the above numbers were recorded in hammond_mrc1_positive_cell_counts_lpc.xlsx, in which the percent of cells which are mrc1+ was calculated from these count data.
# percents were then plotted using GraphPad Prism  
