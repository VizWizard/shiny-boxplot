# remove error message at start - Please select sample data, load a file or paste your data into the text box.
shinyServer(function(input, output, session) {

	library(RColorBrewer)
	library(beeswarm)
	library(vioplot)
	source("MyVioplot.R")
	library(beanplot)	 
	source("boxplot_stats_Function.R")
	
	observe({
		if (input$clearText_button == 0) return()
		isolate({ updateTextInput(session, "myData", label = ",", value = "") })
	})
	# *** Read in data matrix ***
	dataM <- reactive({
		#radioButtons("dataInput", "", list("Load sample data"=1,"Upload file"=2,"Paste data"=3)),
		if(input$dataInput==1){
			if(input$sampleData==1){
				data<-read.table("Boxplot_testData2.csv", sep=",", header=TRUE, fill=TRUE)			
			} else {
				data<-read.table("Boxplot_testData.txt", sep=",", header=TRUE)		
			}
		} else if(input$dataInput==2){
			inFile <- input$upload
			# Avoid error message while file is not uploaded yet
			if (is.null(input$upload))  {return(NULL)}
			# Get the separator
			mySep<-switch(input$fileSepDF, '1'=",",'2'="\t",'3'=";", '4'="") #list("Comma"=1,"Tab"=2,"Semicolon"=3)
			data<-read.table(inFile$datapath, sep=mySep, header=TRUE, fill=TRUE)
		} else { # To be looked into again - for special case when last column has empty entries in some rows
			if(is.null(input$myData)) {return(NULL)} 
			tmp<-matrix(strsplit(input$myData, "\n")[[1]])
			print(tmp)
			mySep<-switch(input$fileSepP, '1'=",",'2'="\t",'3'=";")
			myColnames<-strsplit(tmp[1], mySep)[[1]]
			print(myColnames)
			data<-matrix(0, length(tmp)-1, length(myColnames))
			colnames(data)<-myColnames
			for(i in 2:length(tmp)){
				print(paste(tmp[i],mySep,sep=""))
				myRow<-as.numeric(strsplit(paste(tmp[i],mySep,mySep,sep=""), mySep)[[1]])
				print(myRow)
				print(myRow[-length(myRow)])
				data[i-1,]<-myRow[-length(myRow)]
			}		
		}
		return(data)
	})
	
	# *** The plot dimensions ***
	heightSize <- reactive ({ input$myHeight })
	widthSize <- reactive ({ input$myWidth })

	# *** Determine extent of whisker range ***
	# whiskerDefinition 0 - Tukey (default), 1 - Spear (min/max, range=0), 2 - Altman (5% and 95% quantiles)
	# radioButtons("whiskerType", "", list("Tukey"=0, "Spear"=1, "Altman"=2)),
	myRange <- reactive({
		if(input$whiskerType==0){myRange<-c(-1.5)} 
		else if(input$whiskerType==1){myRange<-c(0)} 
		else if (input$whiskerType==2){myRange<-c(5)}
		return(myRange)
	})
	
	# *** Get boxplot statistics ***
	boxplotStats <- reactive({
		return(boxplot(dataM(), na.rm=TRUE, range=myRange(), plot=FALSE))
	})
	
	# *** Generate the box plot ***
	generateBoxPlot<-function(plotData){
		par(mar=c(5,8,4,2)) # c(bottom, left, top, right)
		myColours<-gsub("\\s","", strsplit(input$myColours,",")[[1]])
		myColours<-gsub("0x","#", myColours)

		myColours2<-gsub("\\s","", strsplit(input$myOtherPlotColours,",")[[1]])
		myColours2<-gsub("0x","#", myColours2)


		nrOfSamples<-ncol(plotData)
		# generate colour vector
		if(length(myColours)==1){
			myColours<-rep(myColours, nrOfSamples)
		} else if(length(myColours) < nrOfSamples){
			myColours<-rep(myColours,times=(round(nrOfSamples/length(myColours)))+1)
		}
		plotPoints<-c() # vector for indices of samples that are to be plotted as points, not as boxplots
		notPlotPoints <- seq(1:nrOfSamples) # samples to plot as boxes/violins/beans
		plotDataM<-plotData
		# Determine plot range
		if(as.numeric(input$myOrientation)==0){		
			if(input$ylimit==""){myLim<-range(plotData,na.rm=TRUE)+c(-1,+1)} else {myLim<-as.numeric(strsplit(input$ylimit,",")[[1]])}
		} else {
			if(input$xlimit==""){myLim<-range(plotData,na.rm=TRUE)+c(-1,+1)} else {myLim<-as.numeric(strsplit(input$xlimit,",")[[1]])}
		}
		# Data point count for each sample
		datapointCounts<-apply(!apply(plotData, 2, is.na),2,sum) # Count number of valid data points for each sample
		# Check if columns with few data points should be plotted as points

		# minimum number of points is 4 -> check that nrOfDataPoints is larger than that		
		mnp<-max(4,input$nrOfDataPoints)
		
		if(input$plotDataPoints==TRUE){
			#toPlot <- seq(1:ncol(plotData))[datapointCounts>=input$nrOfDataPoints] # samples to barplot
			plotPoints <- seq(1:nrOfSamples)[datapointCounts<mnp] # samples to plot as points
			notPlotPoints <- seq(1:nrOfSamples)[datapointCounts>=mnp] # samples to plot as boxes/violins/beans
		}

		# Generate plotDataM matrix such that columns that should be plotted as points are filled with data points outside of visible plot area to 'reserve' spot for points
		for(i in plotPoints){
			plotDataM[,i]<-c(rep(myLim[2]+10, nrow(plotData)-1),myLim[2]+20)
		}

		# *** 1) Vertical boxplots ***
		par(las=1)
		if(as.numeric(input$myOrientation)==0){
			# *** Generate boxplot ***
			if(input$plotType=='0'){
				boxplot(plotDataM, col=myColours, ylab=input$myYlab, xlab=input$myXlab, ylim=myLim,
					cex.lab=input$cexAxislabel/10, cex.axis=input$cexAxis/10, cex.main=input$cexTitle/10, 
					main=input$myTitle, sub=input$mySubtitle, horizontal=as.numeric(input$myOrientation), frame=F, 
					na.rm=TRUE, xaxt="n", range=myRange(), varwidth=input$myVarwidth, notch=input$myNotch) #notch=TRUE
				axis(1,at=c(1:nrOfSamples), labels=colnames(plotData), cex.axis=input$cexAxis/10)
#				text(x=c(1:nrOfSamples), y=rep(myLim[1]-3,nrOfSamples), labels=colnames(plotData), srt=input$xaxisLabelAngle, pos=1)
				# * Add data points to plot if selected *
				if(input$showDataPoints==TRUE){
					if(length(plotPoints)==0){ # all samples are boxplots --> add points for all of them
						if(input$datapointType==0){
							for(i in c(1:nrOfSamples)){ points(rep(i, nrow(plotData)), plotData[,i], col="black") }
						} else { beeswarm(plotData, add=TRUE) }
					} else { # remove the ones that are already plotted as points
						if(input$datapointType==0){
							for(i in c(1:nrOfSamples)[-plotPoints]){ points(rep(i, nrow(plotData)), plotData[,i], col="black") }
						} else { beeswarm(plotData, add=TRUE) }
#						} else { beeswarm(plotData[,-plotPoints], at=c(1:nrOfSamples)[-plotPoints], add=TRUE) }
					}
				}
			} else { # *** Generate violin or bean plot ***
				if(input$otherPlotType==0){ # Violin plot
					vioplot(as.list(data.frame(plotDataM)), col=myColours2, ylim=myLim, cex.axis=input$cexAxis/10, 
						horizontal=as.numeric(input$myOrientation), range=myRange(), border=input$violinBorder)
					title(main=input$myTitle, ylab=input$myYlab, xlab=input$myXlab, cex.main=input$cexTitle/10, cex.lab=input$cexAxislabel/10)
					axis(1,at=c(1:nrOfSamples), labels=colnames(plotData), cex.axis=input$cexAxis/10, sub=input$mySubtitle)
				} else {
					beanplot(data.frame(plotDataM[,notPlotPoints]), at=notPlotPoints, ylim=myLim, horizontal=as.numeric(input$myOrientation), xlim=c(0.5, ncol(plotDataM)+0.5), col=myColours2, border=input$beanBorder)
					title(main=input$myTitle, ylab=input$myYlab, xlab=input$myXlab, cex.main=input$cexTitle/10, cex.lab=input$cexAxislabel/10)
					axis(1,at=c(1:nrOfSamples), labels=colnames(plotData), cex.axis=input$cexAxis/10)				
				}
			}
			# * Add points for samples with less then mnp data points *
			# replace "white" with "black" otherwise data points will not be visible
			for(i in plotPoints){
				if(input$datapointType==0 | input$plotType==1 | (input$datapointType==1 & input$showDataPoints==FALSE)){
					if(myColours[i]!="white"){
						points(rep(i, nrow(plotData)), plotData[,i], col=myColours[i])
					} else {
						points(rep(i, nrow(plotData)), plotData[,i], col="black")				
					}
				}
			}
			if(input$showNrOfPoints==TRUE){text(x=1:ncol(dataM()), y=myLim[1], labels=boxplotStats()$n)}
			# Add mean and CIs for mean
			if(input$addMeans==TRUE & input$plotType=='0'){
				boxplotMeans<-apply(dataM(), 2, mean, na.rm=TRUE)
				points(x=1:ncol(dataM()), y=boxplotMeans, pch="+", cex=2) 
				if(input$addMeanCI==TRUE){ 
					# Calculate the error using the quartile function * Standard error; SE=sd/sqrt(n)
					myQuartile<-1-((1-(as.numeric(input$meanCI)/100))/2)
					myError<-qt(myQuartile, df=(boxplotStats()$n)-1)*(apply(dataM(), 2, sd, na.rm=TRUE)/sapply(boxplotStats()$n, sqrt))
					for(ii in 1:ncol(dataM())) { 
#						lines(y=c(ii,ii), x=c(boxplotMeans[ii]-myError[ii], boxplotMeans[ii]+myError[ii]), col="red") 
						rect(ii-0.05, boxplotMeans[ii]-myError[ii], ii+0.05, boxplotMeans[ii]+myError[ii], col="darkgrey", border="darkgrey") 
					}
					points(x=1:ncol(dataM()), y=boxplotMeans, pch="+", cex=2) 
				}
			}
			
			
		# *** 2) Horizontal boxplots ***
		} else { 
			if(input$plotType=='0'){
				boxplot(plotDataM, col=myColours, ylab=input$myYlab, xlab=input$myXlab, las=1, ylim=myLim,
					cex.lab=input$cexAxislabel/10, cex.axis=input$cexAxis/10, cex.main=input$cexTitle/10, 
					main=input$myTitle, sub=input$mySubtitle, horizontal=as.numeric(input$myOrientation), frame=F, 
					na.rm=TRUE, yaxt="n", range=myRange(), varwidth=input$myVarwidth, notch=input$myNotch) #notch=TRUE
				axis(2,at=c(1:nrOfSamples), labels=colnames(plotData), cex.axis=input$cexAxis/10)
				# Add data points if option has been selected
				if(input$showDataPoints==TRUE){
					if(length(plotPoints)==0){ # all samples are boxplots --> add points for all of them
						if(input$datapointType==0){
							for(i in c(1:nrOfSamples)){ points(plotData[,i], rep(i, nrow(plotData)), col="black") }
						} else { beeswarm(plotData, add=TRUE, horizontal=TRUE) }			
					} else { # remove the ones that are already plotted as points
						if(input$datapointType==0){
							for(i in c(1:nrOfSamples)[-plotPoints]){ points(plotData[,i], rep(i, nrow(plotData)), col="black") }
						} else { beeswarm(plotData, add=TRUE, horizontal=TRUE) }
					}
				}
			} else {
				if(input$otherPlotType==0){ # Violin plot
					vioplot(as.list(data.frame(plotDataM)), col=myColours2[1], ylim=myLim, cex.axis=input$cexAxis/10, 
						horizontal=as.numeric(input$myOrientation), range=myRange(), border=input$violinBorder)
					title(main=input$myTitle, ylab=input$myYlab, xlab=input$myXlab, cex.main=input$cexTitle/10, cex.lab=input$cexAxislabel/10)
					axis(2,at=c(1:nrOfSamples), labels=colnames(plotData), cex.axis=input$cexAxis/10)
				} else { # Bean plot
					beanplot(data.frame(plotDataM), ylim=myLim, horizontal=as.numeric(input$myOrientation), 
					xlim=c(0.5, ncol(plotDataM)+0.5), col=myColours2, border=input$beanBorder, beanlines='median', overallline=beanlines)
					title(main=input$myTitle, ylab=input$myYlab, xlab=input$myXlab, cex.main=input$cexTitle/10, cex.lab=input$cexAxislabel/10)
					axis(2,at=c(1:nrOfSamples), labels=colnames(plotData), cex.axis=input$cexAxis/10)
				}
			}

			# if there are columns with less than x data points, then add the points
			for(i in plotPoints){
				if(input$datapointType==0){
					if(myColours[i]!="white"){
						points(plotData[,i], rep(i, nrow(plotData)), col=myColours[i])
					} else {
						points(plotData[,i], rep(i, nrow(plotData)), col="white")				
					}
				}
			}
			if(input$showNrOfPoints==TRUE){text(y=1:ncol(dataM()), x=myLim[1], labels=boxplotStats()$n)}
			# Add mean and CIs for mean
			if(input$addMeans==TRUE & input$plotType=='0'){
				boxplotMeans<-apply(dataM(), 2, mean, na.rm=TRUE)
				points(y=1:ncol(dataM()), x=boxplotMeans, pch="+", cex=2) 
				if(input$addMeanCI==TRUE){ 
					# Calculate the error using the quartile function * Standard error; SE=sd/sqrt(n)
					myQuartile<-1-((1-(as.numeric(input$meanCI)/100))/2)
					print(myQuartile)
					myError<-qt(myQuartile, df=(boxplotStats()$n)-1)*(apply(dataM(), 2, sd, na.rm=TRUE)/sapply(boxplotStats()$n, sqrt))
					for(ii in 1:ncol(dataM())) { 
#						lines(y=c(ii,ii), x=c(boxplotMeans[ii]-myError[ii], boxplotMeans[ii]+myError[ii]), col="red") 
						rect(boxplotMeans[ii]-myError[ii], ii-0.05, boxplotMeans[ii]+myError[ii], ii+0.05, col="darkgrey", border="darkgrey") 
					}
					points(y=1:ncol(dataM()), x=boxplotMeans, pch="+", cex=2) 
				}
			}
			
		}
		# Add grid based on option selected
		if(input$addGrid==0){} 
		else if(input$addGrid==1){grid()} 
		else if (input$addGrid==2){grid(ny=NA)}
		else if (input$addGrid==3){grid(NA, ny=NULL)}	
	}

	## *** Data in table ***
	output$filetable <- renderTable({
		return(dataM())
	})

	# *** Boxplot (using 'generateBoxPlot'-function) ***
	output$boxPlot <- renderPlot({
		generateBoxPlot(dataM())
	}, height = heightSize, width = widthSize)
	
	## *** Download EPS file ***
	output$downloadPlotEPS <- downloadHandler(
		filename <- function() { paste('Boxplot.eps') },
		content <- function(file) {
			print(widthSize)
			postscript(file, horizontal = FALSE, onefile = FALSE, paper = "special", width = input$myWidth/72, height = input$myHeight/72)
			## ---------------
			generateBoxPlot(dataM())
			## ---------------
			dev.off()
		},
		contentType = 'application/postscript'
	)
	## *** Download PDF file ***
	output$downloadPlotPDF <- downloadHandler(
		filename <- function() { paste('Boxplot.pdf') },
		content <- function(file) {
			print(widthSize)
			pdf(file, width = input$myWidth/72, height = input$myHeight/72)
			## ---------------
			generateBoxPlot(dataM())
			## ---------------
			dev.off()
		},
		contentType = 'application/pdf' # MIME type of the image
	)
	## *** Download SVG file ***
	output$downloadPlotSVG <- downloadHandler(
		filename <- function() { paste('Boxplot.svg') },
		content <- function(file) {
			print(widthSize)
			svg(file, width = input$myWidth/72, height = input$myHeight/72)
			## ---------------
			generateBoxPlot(dataM())
			## ---------------
			dev.off()
		},
		contentType = 'image/svg'
	)

	# *** Output boxplot statistics in table below plot ***
	output$boxplotStatsTable <- renderTable({
		if(input$addMeans){
			M<-rbind(boxplotStats()$stats[c(5,4,3,2,1),],boxplotStats()$n)
			M<-rbind(M, apply(dataM(), 2, mean, na.rm=TRUE))
			rownames(M)<-c("Upper whisker","3rd quartile","Median","1st quartile","Lower whisker", "Nr. of data points", "Mean")
			colnames(M)<-colnames(dataM())
		} else {
			M<-rbind(boxplotStats()$stats[c(5,4,3,2,1),],boxplotStats()$n)
			rownames(M)<-c("Upper whisker","3rd quartile","Median","1st quartile","Lower whisker", "Nr. of data points")
			colnames(M)<-colnames(dataM())
		}
		M
	})
	
	# *** Print figure legend ***
	output$FigureLegend <- renderPrint({
		# Center lines show the medians; box limits indicate the 25th and 75th percentiles as determined by R software; whiskers extend to minimum and maximum values; crosses represent means; bars indicate 95% confidence intervals. n = 100, 76, 16, 76, 41 sample points.
		# Generate vector with pieces of the legend based on user selections
		FL<-vector()
		# Figure legend for boxplot
		if(input$plotType=='0'){
			FL<-c("Center lines show the medians; box limits indicate the 25th and 75th percentiles as determined by R software")
			# one of these three, depending on whisker definition choice:
			# - Spear: "; whiskers extend to minimum and maximum values."
			# - Tukey: "; whiskers extend 1.5 times the interquartile range from the 25th and 75th percentiles; outliers are represented by dots."
			# - Altman: " and whiskers the 5th and 95th percentiles; outliers are represented by dots."
			if(input$whiskerType==0){
				FL<-append(FL, paste("; whiskers extend 1.5 times the interquartile range from the 25th and 75th percentiles, outliers are represented by dots", sep=""))
			} else if(input$whiskerType==1){
				FL<-append(FL, "; whiskers extend to minimum and maximum values")		
			} else {
				FL<-append(FL, paste("; whiskers extend to 5th and 95th percentiles, outliers are represented by dots", sep=""))		
			}
			# Means are added as crosses
			if(input$addMeans & input$plotType=='0'){ FL<-append(FL, c("; crosses represent sample means")) }
			# Confidence intervals of means are displayed as grey bars
			if(input$addMeans & input$addMeanCI & input$plotType=='0'){ FL<-append(FL, paste("; bars indicate ", input$meanCI,"% confidence intervals of the means", sep="")) }
			# Variable width of boxplots
			if(input$myVarwidth){ FL<-append(FL, c("; width of the boxes is proportional to the square root of the sample size")) }
			# Points are plotted on top of boxplots
			if(input$showDataPoints){ FL<-append(FL, c("; data points are plotted as open circles")) }
			# Sample size
			sampleSizes<-boxplotStats()$n
			if(length(unique(sampleSizes))==1){ FL<-append(FL, paste(". n = ", sampleSizes[1], " sample points", sep="")) } 
		  	else { FL<-append(FL, paste(". n = ",paste(sampleSizes, collapse=", "), " sample points", sep="")) }
			FL<-append(FL, ".")
		} else {
			# radioButtons("otherPlotType", "", list("Violin plot"=0, "Bean plot"=1)),
			if (input$otherPlotType=='0'){ # Violin plot
				FL<-c("White circles show the medians; 
				box limits indicate the 25th and 75th percentiles as determined by R software; 
				whiskers extend 1.5 times the interquartile range from the 25th and 75th percentiles; 
				polygons represent density estimates of data and extend to extreme values.")
			} else if (input$otherPlotType=='1') { # Bean plot
				FL<-c("Black lines show the medians; 
				white lines represent individual data points; 
				polygons represent the estimated density of the data.")
				#if(input$beanplotOverall){FL<-append(FL, c("dotted line represents overall "))}
			}
		} # END: other plot types	
		cat(paste(FL, collapse=""))
		#- I am not sure what to put for the notches because we don't add '*'s to the box plots.
	})

	# *** Download boxplot data in csv format ***
	output$downloadBoxplotData <- downloadHandler(
    	filename = function() { "BoxplotData.csv" },
   		content = function(file) {
		write.csv(dataM(), file, row.names=FALSE)
    }) ###

})




