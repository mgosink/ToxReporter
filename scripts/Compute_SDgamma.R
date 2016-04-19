
analyzedata <- function(data = dataname, K=50, mincount = 0,maxcount = 0) {

    #####################################################
    ##### get the datamatrix with column and row names
    datamatrix <- get_data(dataname);
    datarownames <- rownames(datamatrix);
    datacolnames <- colnames(datamatrix);

    #####################################################
    ##### get the matrix of gamma, alpha and beta

    data_fitting <- cont_fitting(datamatrix);
    nonzeroloc <- data_fitting$nonzeroloc;
    gammamatrix <- data_fitting$gammamatrix;
    gammamatrix <- as.matrix(gammamatrix);

    ####################################################
    ##### simulate the independent data according to the realdata
    datainde <- cont_simulate(datamatrix,sum(datamatrix),T);

    ##### get the estimation of the parameter for the independent data
    inde_fitting <- cont_fitting(datainde);
    gammamatrix_inde <- inde_fitting$gammamatrix;
    nonzerolocinde <- inde_fitting$nonzeroloc;

    #####################################################
    ##### find the standard deviation from the simulated data
    ##### the group variable is the observed counts of the simulated independent data
    gammasd <- cal_sd(datainde,gammamatrix_inde,nonzerolocinde);

    ###############
    ##### smoothed the estimation of the standard deviation
    gammasdsm <- sdsmoothed(gammasd,100);

    ###############
    ##### use smoothed version to standardize the gamma
    ##### the group variable is the observed counts
    sdgammamatrix <- sdscores(datamatrix,nonzeroloc,gammamatrix,gammasd);

#    plot_scores_counts(sdgammamatrix,nonzeroloc,datamatrix,datarownames,datacolnames,
#                       dataname=dataname,mincount=mincount,maxcount=maxcount,yname='standardized scores');

    lar <- lscores(datamatrix,sdgammamatrix,nonzeroloc,K,datarownames,datacolnames,mincount,maxcount);

    #return(list(sdGamma = sdgammamatrix,sigloc = lar$largeindex,signames = lar$largenames,nonzeroloc = nonzeroloc));
    return(sdgammamatrix)

}



##########################################################################################
### load the data and get the column and row names
### get_data('name_of_data.csv'): 
### description: get the data into data.frame with column and row names
### parameter: name_of_data.csv is the name of the data that on the dard drive.

get_data <- function(dataname){
         datamatrix <- read.delim(file = dataname,header = T);
         datarownames <- datamatrix[,1];
         datamatrix <- datamatrix[,-1];
         datacolnames <- colnames(datamatrix);
         rownames(datamatrix) <- datarownames;
         colnames(datamatrix) <- datacolnames;          
         return(datamatrix);

} 



##########################################################################################
### cont_fitting(datamatrix): 
### description: get the estimation of parameter gamma, alpha and beta

#cont_fitting <- function (datamatrix, sudocounts = 0.0001){
#cont_fitting <- function (datamatrix, sudocounts = 0.01){
cont_fitting <- function (datamatrix, sudocounts = 2.0){

       realdim <- dim(datamatrix);   # find matrix dimensions
       datarownames <- rownames(datamatrix);
       datacolnames <- colnames(datamatrix);
       nonzeroloc <- datamatrix != 0;   #  build a matrix of non zero values
      
       datamatrix <- datamatrix + sudocounts;   # add pseudo counts to matrix
       con <- log(sum(sum(datamatrix)));  # add up everything and then take the log
       alpha <- log(apply(datamatrix,1,sum)) - con;
       beta <- log(apply(datamatrix,2,sum)) - con;
       alphamatrix <- alpha %*% matrix(rep(1,realdim[2]),1,realdim[2]);
       betamatrix <- matrix(rep(1,realdim[1]),realdim[1],1) %*% beta;
       gammamatrix <- log(datamatrix) - alphamatrix - betamatrix - con;
       colnames(alphamatrix) <- datacolnames;
       rownames(alphamatrix) <- datarownames;
       colnames(betamatrix) <- datacolnames;
       rownames(betamatrix) <- datarownames;
       colnames(gammamatrix) <- datacolnames;
       rownames(gammamatrix) <- datarownames;
       return(list(con = con, nonzeroloc = nonzeroloc,
       alphamatrix = alphamatrix,betamatrix = betamatrix,gammamatrix = gammamatrix));               
          
}



##########################################################################################
#### give the matrix and the total number of counts.
#### simulate the data according to the matrix, 
#### N is the number of total counts
#### indep = T using the marginal distribution to simulate the data
#### indep = F using the conditional distribution to simulate the data

cont_simulate <- function(datamatrix, N, indep) {
            totalcounts <- sum(datamatrix);
            realdim <- dim(datamatrix);
            rowpro <- apply(datamatrix,1,sum)/totalcounts;
            colpro <- apply(datamatrix,2,sum)/totalcounts;
            condicolpro <- datamatrix / (apply(datamatrix,1,sum) %*% matrix(rep(1,realdim[2]),1,realdim[2]));
            rowloc <- sample(1:realdim[1],N,replace = T,prob = rowpro);
            simulatedata <- matrix(rep(0,prod(realdim)),realdim[1],realdim[2]);
            
            if (indep == T){
               print('simulate according to the independence model')
               colloc <- sample(1:realdim[2],N,replace = T,prob = colpro);
               loc <- rowloc + (colloc - 1)*realdim[1];
               loccounts <- hist(loc,breaks = 1:(prod(realdim)+1),include.lowest=T,right=F,plot=F);
               simulatedata <- simulatedata + matrix(loccounts$counts,realdim[1],realdim[2]);
               }
            else {
               print('simulate according to the saturated model')
               rowcounts <- hist(rowloc,breaks = 1:(realdim[1]+1),include.lowest=T,right=F,plot=F);
               rowcounts <- rowcounts$counts;
               for (i in 1:realdim[1]){
                    colloci <- sample(1:realdim[2],rowcounts[i],replace=T,prob = condicolpro[i,]);
                    colcountsi <- hist(colloci, breaks = 1:(realdim[2]+1),freq = T,include.lowest=T,right=F,plot=F);
                    simulatedata[i,] = simulatedata[i,] + colcountsi$counts;
                   }
               }
             return(simulatedata)
}




##########################################################################################
#### find the sd of scores based on the datamatrix. 
#### datamatrix is the matrix that is served as group variable
#### nonzeroloc is the location with nonzero counts of the data 
#### from which scorematrix is calculated from 

cal_sd <- function(datamatrix,scorematrix,nonzeroloc){

          datamatrix = as.matrix(datamatrix);
          databreaks = floor(min(datamatrix)):(floor(max(datamatrix))+1); 
          lenbreaks <- length(databreaks);
          sdindevector <- matrix(0,lenbreaks-1,2);          
          sdindevector[,1] <- databreaks[1:(lenbreaks-1)];          
                   
          levelcounts <- hist(datamatrix,breaks = databreaks,include.lowest=T,right=F,plot=F)$counts;   
         
          sdpoint = 1;

          for (ii in 1:(lenbreaks-1)) {
               icounts = levelcounts[ii];
               if (icounts == 0) {
                  sdindevector[ii,2] <- sdpoint;
                  }
               else  {
                    tmploc <- (datamatrix >= databreaks[ii]) & (datamatrix < databreaks[ii+1]) & nonzeroloc;
                    iran = 1;
                    while ((sum(tmploc) <= 6) & (iran <= 4))  {                      
                          tmploc <- (datamatrix >= databreaks[max(ii-iran,1)]) & 
                                    (datamatrix < databreaks[min(ii+iran+1,lenbreaks)]) & 
                                     nonzeroloc;
                          iran = iran + 1;
                          }
                    if (iran == 5)  {
                         sdindevector[ii,2] <- sdpoint;
                         }
                    else  {
                          sdpoint <- sd(scorematrix[tmploc]); 
                          sdindevector[ii,2] <- sdpoint;
                         }
                    }
              }
           
          return(sdindevector);
}




##########################################################################################
### sdsmoothed(countsd,scounts=20,ecounts=25,lcounts=100)
### description: for large count, the occurence is too small to estiamte the standard deviation. 
###              so smooth the sd is equivalent to borrow the data from eighboring counts to estimate
###              the standard deviation. 
### parameter: 1) countsd: a vector of standard deviation of scores estimated from independent data.
###            2) countsd[scount+1:counts] are the input of smoothed
###            3) countsd[ecounts+1:lcounts] are the cells that are replaced by smoothed data

sdsmoothed <- function(countsd,scounts = 20,sdf = 10){
           
           sdsmooth <- countsd;
           lencountsd <- dim(countsd)[1];

           # if (length(countsd)<lcounts){
           #    print('the length of sd is smaller than the largest count');
           #    return(sdsmoothed);              
           #     }

           # sdsmoothed[1:ecounts] <- countsd[1:ecounts];    
           # tmp <- lowess(countsd[(scounts+1):lcounts])$y; 
           # sdsmoothed[(ecounts+1):lcounts] <- tmp[(ecounts-scounts+1):(lcounts-scounts)];    
           # return(sdsmoothed); 
            
           tmpsmline <- smooth.spline(countsd,df = sdf)$y;
           sdsmooth[scounts:lencountsd,2] <- tmpsmline[scounts:lencountsd];

           return(sdsmooth)
           
}



##########################################################################################
### sdscores(datamatrix,scores,countsd,mincount = 1,maxcount = 100)
### description: the standardized scores for the counts between 1 and 100
### parameter: 1) datamatrix: original data
###            2) estimated scores from datamatrix
###            3) estimated sd for scores 
###            4) mindata and maxdata is the range that the standard deviation of the score is calculated

sdscores <- function(datamatrix,nonzeroloc,scores,countsd){

                         
             sdvector <- countsd[,2];     
             
             groupvariable <- floor(datamatrix[nonzeroloc]) + 1;
             countlength <- dim(countsd)[1];
             groupvariable <- groupvariable * (groupvariable <= (countlength)) + 
                              countlength * (groupvariable > countlength);  

             tmpscores <- scores[nonzeroloc];
             tmpscores <- tmpscores/sdvector[groupvariable];
             
             scores[nonzeroloc] <- tmpscores;           
             return(scores);
}



##########################################################################################
#### locate the largest scores
#### 

lscores <- function(datamatrix,scoresmatrix,nonzeroloc,K,datarownames,datacolnames,mincount,maxcount) {
               
               effectloc <- which((datamatrix >= mincount) & (datamatrix <= maxcount) &
                                  nonzeroloc);        
               effectscore <- scoresmatrix[effectloc];
               maxscore <- max(effectscore);
               minscore <- min(effectscore);
               if (K > length(effectloc)){
                   cat('K is too large');
                   K <- length(effectloc);
                   }
               effpropor <- K/length(effectloc) * 10; 
               
               tmpsum <- 0;
}

##########################################################################################
plot_scores_counts <- function(scorematrix,nonzeroloc,datamatrix,datarownames,datacolnames,
                      dataname='real data',mincount=1,maxcount=100,xname = 'Counts',yname = 'scores'){
                    
          plotloc <- (datamatrix >= floor(mincount)) & 
                     (datamatrix <= ceiling(maxcount)) & 
                      nonzeroloc;  

          plotloc2 <- index1t2(dim(datamatrix),which(plotloc));
          
          drugnames <- datarownames[plotloc2[,1]];
          adnames <- datacolnames[plotloc2[,2]];
          combnames <- paste(drugnames,adnames,sep=' x ');           
   
          datamatrix2 <- datamatrix[plotloc];
          scorematrix2 <- scorematrix[plotloc];    

          groupcolor <- floor(datamatrix2);
          coltmp <- (26 + groupcolor) %% length(colors());
          colmatrix <- colors()[coltmp+1]; 
          
          plot(datamatrix2,scorematrix2,
          col = colmatrix,pch = 20,xlab = xname, 
          ylab = yname, main=dataname);

          identify(datamatrix2,scorematrix2,combnames)

}





##### transform the location in vector into 2 dimension loc
##### realdim is the dimension of the matrix
##### c is the vector of the location in one dimension

index1t2 <- function(realdim, loc){

           loclength <- length(loc);
           loc <- matrix(loc,loclength,1);
           # rowloc <- loc %% realdim[1];
           # colloc <- (loc - rowloc)/realdim[1] + 1;
           colloc <- ceiling(loc/realdim[1]);
           rowloc <- loc - (colloc - 1) * realdim[1];
           return(cbind(rowloc,colloc));
}

