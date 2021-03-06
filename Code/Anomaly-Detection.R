#If required
# install.packages("ggplot2")
# install.packages("jsonlite", repos="http://cran.r-project.org")
# install.packages("readr")
library(readr)
library(ggplot2)
library(sqldf)
library(httr)
library(RCurl)
library(bitops)
library(jsonlite)
library(stringr)

#Configuration Data
# pulling data from Json
vsampleConfigFileName <- fromJSON(________________________)
View(vsampleConfigFileName)
jsonstr <- vsampleConfigFileName
f_getconfigval <- function(injsonstr, invarname)
{
  injsonstr$paramvalue[injsonstr$paramname==invarname]
}

# Read json configuration parametric values
# Name of the column which holds the Time stamp of data recorded by Sensor
v_coltimestamp <- f_getconfigval(jsonstr, "coltimestamp")
# Name of the column which holds the Sensor identification
v_colsensorid <- f_getconfigval(jsonstr, "colsensorid")
# Name of the column that stores the values measured by sensor
v_colsensorvalue <- f_getconfigval(jsonstr, "colsensorvalue")
# Sensor ID for which the analysis needs to be applied
v_sensorid <- f_getconfigval(jsonstr, "sensorid")
# Time format of the data in the data frame
v_datatimeformat <- f_getconfigval(jsonstr, "datatimeformat")
# Time zone for the Time stamps
v_intimezone <- f_getconfigval(jsonstr, "intimezone")
# Time format which is used for specifying the
# time ranges in the below paraneters
v_rangetimeformat <- f_getconfigval(jsonstr, "rangetimeformat")
# Start Time for first series Time range
v_Pfrom <- f_getconfigval(jsonstr, "Pfrom")
# End Time for first series Time range
v_Pto <- f_getconfigval(jsonstr, "Pto")
# Start Time for second series Time range
v_Cfrom <- f_getconfigval(jsonstr, "Cfrom")
# End Time for second series Time range
v_Cto <- f_getconfigval(jsonstr, "Cto")
# Set the threshold percentage of change if detected
v_thresholdpercent <- as.numeric(f_getconfigval(jsonstr, "thresholdpercent"))

# Cross verify configuration parametric values
print(c(v_coltimestamp, v_colsensorid, v_colsensorvalue, v_sensorid,
        v_datatimeformat, v_intimezone, v_rangetimeformat, v_Pfrom,
        v_Pto, v_Cfrom, v_Cto, v_thresholdpercent))

###########################################################################################################################

#Sensor Data
# Pull csv file from Github

urlfile = (_____________________________________________________________________________________)
mydata <- read.csv(url(urlfile))

head(mydata)
View(mydata)

# Sort data by time stamp in ascending order
mydata <- mydata[with(mydata,
                      order(SensorID,
                            as.POSIXct(TimeStamp,format = v_datatimeformat, tz = v_intimezone))),];

###########################################################################################################################

# Function to split data into 2 datasets: Previous, Current
# IN: Standard Data Frame, SensorID,
#     Previous From Time stamp, Previous To Time stamp, 
#     Current From Time Stamp, Current To Time Stamp
# OUT: Data series <br/>
#     series 1 (SensorID, TimeStamp, SensorValue),
#     series 2 (SensorID, TimeStamp, SensorValue)

f_splitdataseries <- function(SensorID, Intimeformat, Datatimeformat, PFrom, PTo, CFrom, CTo)
{
  PFromPOSIX = as.POSIXct(PFrom, format=Intimeformat, tz="GMT", usetz=FALSE);
  PToPOSIX = as.POSIXct(PTo, format=Intimeformat, tz="GMT", usetz=FALSE);
  CFromPOSIX = as.POSIXct(CFrom, format=Intimeformat, tz="GMT", usetz=FALSE);
  CToPOSIX = as.POSIXct(CTo, format=Intimeformat, tz="GMT", usetz=FALSE);
  
  mydata$TimeStampPOSIX <- as.POSIXct(mydata$TimeStamp, 
                                       format=Datatimeformat, tz="GMT", usetz=FALSE);
  
  series1 = mydata[which(mydata$SensorID ==SensorID & 
                            mydata$TimeStampPOSIX >= PFromPOSIX & mydata$TimeStampPOSIX < PToPOSIX),];
  series2 = mydata[which(mydata$SensorID ==SensorID & 
                            mydata$TimeStampPOSIX >= CFromPOSIX & mydata$TimeStampPOSIX < CToPOSIX),];
  return(list(series1, series2));
}

# Running the above function, splitting data into 2
s = f_splitdataseries (SensorID=v_sensorid,
                       Intimeformat=v_rangetimeformat, Datatimeformat=v_datatimeformat,
                       PFrom=v_Pfrom, PTo=v_Pto,
                       CFrom=v_Cfrom, CTo=v_Cto)

# Unpack the 2 list of data frames
series1 <- s[[1]]
series2 <- s[[2]]

head(series1)
head(series2)

###########################################################################################################################

# Visualise/Analyse data

f_plot2lines <- function(x1, y1, x2, y2)
{
  plot(y1,type="l",col="green",xlab=" ", ylab=" ",pch=21,xaxt="n",yaxt="n")
  par(new=T)
  plot(y2,type="l",col="red",xlab="Time", ylab="Sensor Values",pch=21,xaxt="n",yaxt="n")
  axis(2,las=3,cex.axis=0.8)
  axis(1,at=c(1:length(x1)),c(x1),las=2,cex.axis=0.4)
  title("Sensor readings by Time overlay")
  par(new=F)
}

# Line plot of the 2 Data series
f_plot2lines(x1 <- series1$TimeStamp, y1 <- series1$SensorValue,
             x2 <- series2$TimeStamp, y2 <- series2$SensorValue)

# Function to plot the box plots for both the distributions <br/>
# Time series order does not matter for this <br/>
#     IN parameters: (Sensorvalues-series 1, Sensorvalues-series 2)

f_plot2boxes <- function(s1sensorvalue, s2sensorvalue)
{
  data_list = NULL
  col_list = c("green", "blue")
  names_list = c("Previous", "Current")
  
  data_list = list()
  data_list[[1]] = s1sensorvalue
  data_list[[2]] = s2sensorvalue
  
  # dev.new() # Works in PC only
  boxstats <- boxplot.stats(data_list[[1]], coef=1.57, do.conf = TRUE, do.out = TRUE)
  #par(new=T)
  boxplot(data_list, las = 2, col = col_list, ylim=c(-2.0,70),
          names= names_list,
          mar = c(12, 5, 4, 2) + 0.1,
          main="Change point detection",
          sub=paste("Spread of Sensor reading distributions", ":", sep=""),
          ylab="Sensor Readings", 
          coef=1.57, do.conf = TRUE, do.out = TRUE)
  abline(h=boxstats$stats, col="green", las=2)
}

# Plot the 2 box plots for the distribution
f_plot2boxes(s1sensorvalue = series1$SensorValue,
             s2sensorvalue = series2$SensorValue)

# Function to calculate the stats for both the series <br/>
# Avg, Median, p1sd, p2sd, p3sd, n1sd, n2sd, n3sd, q0, q1, q2, q3, q4, f1range, <br/>
#      iqrange, f2range, sku, kurt, outliers

f_seriesstats <- function(series)
{
  boxstats <- boxplot.stats(series, coef=1.57, do.conf = TRUE, do.out = TRUE)
  smin <- min(series)
  smax <- max(series)
  smean <- mean(series)
  #Spread measures
  sq0 <- boxstats$stats[1]
  sq1 <- boxstats$stats[2]
  sq2 <- boxstats$stats[3]
  sq3 <- boxstats$stats[4]
  sq4 <- boxstats$stats[5]
  siqr <- (sq3 - sq1)
  # Normal distribution
  s1sd <- sd(series)
  s1sdp <- smean + s1sd
  s1sdn <- smean - s1sd
  s2sdp <- smean + (2*s1sd)
  s2sdn <- smean - (2*s1sd)
  s3sdp <- smean + (3*s1sd)
  s3sdn <- smean - (3*s1sd)
  # Outlier counts @ 2sd
  s2sdout <- sum(series > s2sdp) + sum(series < s2sdn)
  # return(list(smin, smax, smean, sq0, sq1, sq2, sq3, sq4, siqr, s1sd, s1sdp,
  # s1sdn, s2sdp, s2sdn, s3sdp, s3sdn))
  return(list(smin=smin, smax=smax, smean=smean,
              sq0=sq0, sq1=sq1, sq2=sq2, sq3=sq3, sq4=sq4, siqr=siqr,
              s1sd=s1sd, s1sdp=s1sdp, s1sdn=s1sdn,
              s2sdp=s2sdp, s2sdn=s2sdn, s3sdp=s3sdp, s3sdn=s3sdn))
}

###########################################################################################################################

# Compute the statistics for both series and check results
s1stats <- f_seriesstats(series1$SensorValue)
s2stats <- f_seriesstats(series2$SensorValue)

## Function to calculate change point deviatrion percentages
f_changepercent <- function(val1, val2)
{
  return(((val2-val1)/val1)*100)
}

# Calculate percentage deviation for individual stats
f_serieschangepercent <- function(series1stats, series2stats)
{
  n <- length(series1stats)
  cols=names(series2stats)
  cpdf <- data.frame(statname=character(), series1val = numeric(), 
                     series2val=numeric(), changeper=numeric());
  for (i in 1:length(series2stats))
  {
    newrow = data.frame(statname=cols[i], 
                        series1val=series1stats[[i]], 
                        series2val=series2stats[[i]], 
                        changeper=f_changepercent(series1stats[[i]], series2stats[[i]]))
    cpdf <- rbind(cpdf, newrow)
  }
  return(cpdf)
}

# Calculate overall percentage deviation and detect change point
f_detectchangepoint <- function(dfcp, threshold)
{
  # Overall percentage deviation
  newrow = data.frame(statname='overall',
                      series1val=NA,
                      series2val=NA,
                      changeper=mean(abs(dfcp$changeper)))
  dfcp <- rbind(dfcp, newrow)
  # Overall change point percentage
  changepointper <- dfcp[which(dfcp$statname=="overall"),c("changeper")]
  # Mark change point at threshold %
  if(changepointper > threshold)
  {return(paste("Change Point DETECTED exceeding threshold: ",threshold,"% ", sep=""))}
  else
  {return(paste("Change Point NOT DETECTED at threshold: ",threshold,"% ", sep=""))}
}

# Overall change percentage in key statistics
dfallstats <- f_serieschangepercent(s1stats, s2stats)
print(dfallstats)
# Detect changepoint
f_detectchangepoint(dfallstats, v_thresholdpercent)