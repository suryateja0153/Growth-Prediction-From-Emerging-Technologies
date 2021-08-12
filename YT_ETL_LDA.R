# Author: Suryateja Chalapati
# Date: 5/1/2021

# Load libraries
library(tm)
library(tidytext)
library(topicmodels)
library(ggplot2)
library(dplyr)
library(tidyr)
#install.packages('reshape2')

parent.folder <- "C:/Users/surya/Downloads/Career/M.S. [2020-22]/3.Spring_2021/[ISM6905.001S21.12437 Independent Study]/YT_Corpus [All]/YT_Corpus [2020-2021]"
sub.folders <- list.dirs(parent.folder, recursive=TRUE)[-1]

# Run scripts in sub-folders 
for(i in sub.folders) {
  
  tryCatch({
    
    setwd(i)
    
    # Load files into corpus
    filenames <- list.files(getwd(), recursive = TRUE, pattern = "*.txt")
    
    # Read files into a character vector
    files <- lapply(filenames, readLines)
    
    # Create corpus from vector
    docs <- Corpus(VectorSource(files))
    
    # Remove non-alphanumeric characters
    remove_alphanum <- content_transformer(function(x, pattern) gsub("[^\x30-\x7A]+", " ", x))
    docs <- tm_map(docs, remove_alphanum)
    
    # Remove common English stopwords
    docs <- tm_map(docs,removeWords,stopwords("english"))
    
    # Remove punctuation
    docs <- tm_map(docs,removePunctuation)
    
    # Remove numbers
    docs <- tm_map(docs,removeNumbers)
    
    # Remove whitespace
    docs <- tm_map(docs,stripWhitespace)
    
    # Stem document - remove word suffixes
    docs <- tm_map(docs,stemDocument)
    
    # Define and eliminate all custom stopwords
    myStopwords <- c("logsdon","baab","baabs","baabre","can","one","and","like","just","gonna","know",
                     "really","right","going","get","well","lot","actually","new",
                     "will","much","way","and","see","make","look",
                     "also","able","say","back","got","take","great",
                     "many","next","using","around","thing","two",
                     "looking","said","kind","come","put","yeah",
                     "even","still","ago","every","three","five","gonna",
                     "okay","whether","seen","six","there","this",
                     "but","you","want","thats",
                     "folks","sure","run","and")
    docs <- tm_map(docs,removeWords,myStopwords)
    
    # Create document-term matrix
    params <- list(minDocFreq = 1,removeNumbers = TRUE,stopwords = TRUE,stemming = TRUE,weighting = weightTf)
    
    dtm <- DocumentTermMatrix(docs, control = params)
    # Convert rownames to filenames
    rownames(dtm) <- filenames
    # Collapse matrix by summing over columns
    dtm.matrix <- as.matrix(dtm)
    freq <- colSums(dtm.matrix)
    # Length should be total number of terms
    length(freq)
    # Create sort order (descending)
    ord <- order(freq,decreasing=TRUE)
    # List all terms in decreasing order of freq and write to disk
    freq[ord]
    write.csv(freq[ord],"word_freq.csv")
    
    # Set parameters for Gibbs sampling
    burnin <- 4000
    iter <- 2000
    thin <- 500
    seed <-list(2003,5,63,100001,765)
    nstart <- 5
    best <- TRUE
    
    # Number of topics
    k <- 5
    
    # Run LDA using Gibbs sampling
    
    # Class "TopicModel" contains
    # call: Object of class "call".
    # Dim: Object of class "integer"; number of documents and terms.
    # control: Object of class "TopicModelcontrol"; options used for estimating the topic model.
    # k: Object of class "integer"; number of topics.
    # terms: Vector containing the term names.
    # documents: Vector containing the document names.
    # beta: Object of class "matrix"; logarithmized parameters of the word distribution for each topic.
    # gamma: Object of class "matrix"; parameters of the posterior topic distribution for each document.
    # iter: Object of class "integer"; the number of iterations made.
    # 12 TopicModel-class
    # logLiks: Object of class "numeric"; the vector of kept intermediate log-likelihood values of the
    # corpus. See loglikelihood how the log-likelihood is determined.
    # n: Object of class "integer"; number of words in the data used.
    # wordassignments: Object of class "si
    
    ldaOut <- LDA(dtm, k, method="Gibbs", control=list(nstart=nstart, seed = seed, best=best, burnin = burnin, iter = iter, thin=thin))
    
    # write out results
    # docs to topics
    
    ldaOut.topics <- as.matrix(topics(ldaOut))
    write.csv(ldaOut.topics,file=paste("LDAGibbs",k,"DocsToTopics.csv"))
    
    # Top N terms in each topic
    ldaOut.terms <- as.matrix(terms(ldaOut,100))
    write.csv(ldaOut.terms,file=paste("LDAGibbs",k,"TopicsToTerms.csv"))
    
    # Probabilities associated with each topic assignment
    topicProbabilities <- as.data.frame(ldaOut@gamma)
    write.csv(topicProbabilities,file=paste("LDAGibbs",k,"TopicProbabilities.csv"))
    
    #Find relative importance of top 2 topics
    topic1ToTopic2 <- lapply(1:nrow(dtm),function(x)
      sort(topicProbabilities[x,])[k]/sort(topicProbabilities[x,])[k-1])
    
    #Find relative importance of second and third most important topics
    topic2ToTopic3 <- lapply(1:nrow(dtm),function(x)
      sort(topicProbabilities[x,])[k-1]/sort(topicProbabilities[x,])[k-2])
    
    #write to file
    write.csv(topic1ToTopic2,file=paste("LDAGibbs",k,"Topic1ToTopic2.csv"))
    write.csv(topic2ToTopic3,file=paste("LDAGibbs",k,"Topic2ToTopic3.csv"))
    
    # create the visualization
    
    ap_topics <- tidy(ldaOut, matrix = "beta")
    
    # ap_top_terms <- ap_topics %>%
    #   group_by(topic) %>%
    #   top_n(20, beta) %>%
    #   ungroup() %>%
    #   arrange(topic, -beta)
    # 
    # ap_top_terms %>%
    #   mutate(term = reorder(term, beta)) %>%
    #   ggplot(aes(term, beta, fill = factor(topic))) +
    #   geom_col(show.legend = FALSE) +
    #   facet_wrap(~ topic, scales = "free") +
    #   coord_flip()
    
    beta_spread <- ap_topics %>%
      mutate(topic = paste0("topic", topic)) %>%
      spread(topic, beta) %>%
      filter(topic1 > .001 | topic2 > .001) %>%
      mutate(log_ratio = log2(topic2 / topic1))
    
    write.csv(beta_spread,"beta_spread.csv")
    
  }, error=function(e) {cat("ERROR :", conditionMessage(e), "\n")} )
}
