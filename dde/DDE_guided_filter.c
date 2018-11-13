//Display and detail enhancement for high-dynamic-range infrared images
//https://www.researchgate.net/publication/258338485_Display_and_detail_enhancement_for_high-dynamic-range_infrared_images

#include "DDE_guided_filter.h"


///////////////////////////////////
//init filter params and image size

//sizeW - size window in Guided Filter (1 x sW)
//eps - parameter of smothing level in Guided filter
//direct - direct of filtering (horizontal/vertical)
void initStripParams(StripParams *io_params, unsigned int sizeW, float eps)
{
#ifdef STATIC_ARRAYS
	io_params->sizeW = STRIP_CANVAS;
#else
	io_params->sizeW = sizeW;
#endif
	io_params->eps = eps;
}


//sizeW - size window in Guided filter (3x3, 5x5, 7x7)
//eps - parameter of smothing level in Guided filter
//T - min threshold in Histogram projection
//n_valid - max value of pixel (= size of histogram)
void initAgcParams(AgcParams *io_params, unsigned int sW, unsigned int max_detail, float eps, float eps_div, unsigned int T)
{
#ifdef STATIC_ARRAYS
	io_params->sizeW = DDE_CANVAS;
#else
	io_params->sizeW = sW;
#endif
	io_params->eps = eps;
	io_params->eps_div = eps_div;
	io_params->max_detail = max_detail;
	io_params->T = T;
}


void initSizeParams(ImgSize *io_size, int width, int height, int nBits)
{
#ifdef STATIC_ARRAYS
	io_size->width = IMG_WIDTH;
	io_size->height = IMG_HEIGHT;
#else
	io_size->width = width;
	io_size->height = height;
#endif
	io_size->n_valid = MAX_VALID;
}


/////////////////////////////////////////////
//algorithm (Agc + Guided Image Filter (GIF))
void runDDEfilter(uInt16 *io_imNoisy, AgcParams *p_params, ImgSize *p_size)
{

#ifndef STATIC_ARRAYS
	float *a1GIF = (float *)malloc(sizeof(float) * p_size->width * p_size->height);
	float *a2GIF = (float *)malloc(sizeof(float) * p_size->width * p_size->height);
	float *MaGIF = (float *)malloc(sizeof(float) * p_size->width * p_size->height);
	Int16 *imBase1 = (Int16 *)malloc(sizeof(Int16) * p_size->width * p_size->height);
	Int16 *imBase2 = (Int16 *)malloc(sizeof(Int16) * p_size->width * p_size->height);
	Int16 *imBaseP = (Int16 *)malloc(sizeof(Int16) * p_size->width * p_size->height);
	Int16 *imDetail = (Int16 *)malloc(sizeof(Int16) * p_size->width * p_size->height);
	Int16 *imDetailP = (Int16 *)malloc(sizeof(Int16) * p_size->width * p_size->height);
	Int16 *imFinal = (Int16 *)malloc(sizeof(Int16) * p_size->width * p_size->height);
#endif

	runGIFfilter(io_imNoisy, imBase1, a1GIF, p_params, p_size);
	p_params->eps /= p_params->eps_div;
	runGIFfilter(io_imNoisy, imBase2, a2GIF, p_params, p_size);
	runHistProtection(imBase2, imBaseP, p_params, p_size);
	//imDetail = imBase2 - imBase1
	subImage(imBase2, imBase1, imDetail, p_size);
	runGainMaskEnhancement(imDetail, imDetailP, a1GIF, a2GIF, p_params, p_size);
	//imFinal = imBaseP + imDetailP
	addImage(imBaseP, imDetailP, imFinal, p_size);
	
	copyImage(io_imNoisy, imFinal, p_size);

#ifndef STATIC_ARRAYS
	free(a1GIF);
	free(a2GIF);
	free(imBase1);
	free(imBase2);
	free(imBaseP);
	free(imDetail);
	free(imDetailP);
	free(imFinal);
#endif
}


/////////////////////////////////////////////
//Strip Noise Removal
void runStripfilter(uInt16 *io_imNoisy, StripParams *p_params, ImgSize *p_size)
{
#ifndef STATIC_ARRAYS
	Int16 *imSmooth = (Int16 *)malloc(sizeof(Int16) * p_size->width * p_size->height);
	Int16 *imTextureN = (Int16 *)malloc(sizeof(Int16) * p_size->width * p_size->height);
	Int16 *imStrip = (Int16 *)malloc(sizeof(Int16) * p_size->width * p_size->height);
	Int16 *imTexture = (Int16 *)malloc(sizeof(Int16) * p_size->width * p_size->height);
	Int16 *imTemp = (Int16 *)malloc(sizeof(Int16) * p_size->width * p_size->height);
#endif

	//add strip noise to image 
	//unsigned int delta = 300;
	//unsigned int strip_width = 3;
	//addStrip(io_imNoisy, delta, strip_width, p_size);

	//1D row guided filter
	p_params->direct = horizontal;
	runGIFstrip((Int16*)io_imNoisy, (Int16*)io_imNoisy, imSmooth, imTextureN, p_params, p_size);
	//1D column guided filter
	p_params->direct = vertical;
	runGIFstrip(imTextureN, imTextureN, imStrip, imTexture, p_params, p_size);
	//Subtract strips from Noisy image
	subImage((Int16*)io_imNoisy, imStrip, imTemp, p_size);
	copyImage(io_imNoisy, imTemp, p_size);

#ifndef STATIC_ARRAYS
	free(imSmooth);
	free(imTextureN);
	free(imStrip);
	free(imTexture);
	free(imTemp);
#endif
}

//Guided image filter, guided img != input img (for Strip Noise Removal) 
void runGIFstrip(Int16 *i_imNoisy, Int16 *i_imGuide, Int16 *o_imSmooth, Int16 *o_imTexture, StripParams *p_params, ImgSize *p_size)
{
	int width = p_size->width;
	unsigned int height = p_size->height;
	unsigned int k_max = p_size->n_valid;
	unsigned int sW = p_params->sizeW;
	Int16 max_k = p_size->n_valid;
	double eps = p_params->eps;
	enum direct_t direct = p_params->direct;
	//size of canvas image
	unsigned int cnv_width = width + (sW >> 1) * 2;
	unsigned int cnv_height = height + (sW >> 1) * 2;

	int i, j, m, n;
	Int16 out_img;
	double muN, sigmaGN, muG, sigmaGG;
	double sum_a, sum_b;
	//set border for loop
	//delta_h - horizontal, delta_v - vertical
	int delta_h = (direct == horizontal) ? sW / 2 : 0;
	int delta_v = (direct == vertical) ? sW / 2 : 0;

#ifndef STATIC_ARRAYS
	Int16 *imCanvasStripN = (Int16 *)malloc(sizeof(float) * cnv_width * cnv_height);
	Int16 *imCanvasStripG = (Int16 *)malloc(sizeof(float) * cnv_width * cnv_height);
	float *aStrip = (float *)malloc(sizeof(float) * cnv_width * cnv_height);
	float *bStrip = (float *)malloc(sizeof(float) * cnv_width * cnv_height);
#endif

#ifdef _OPENMP
	omp_set_num_threads(nThreads);
	#pragma omp parallel for private(j)
#endif
	for (i = 0; i < height; i++)
	{
		for (j = 0; j < width; j++)
		{
			imCanvasStripN[(i + sW/2) * cnv_width + (j + sW/2)] = i_imNoisy[i * width + j];
			imCanvasStripG[(i + sW/2) * cnv_width + (j + sW/2)] = i_imGuide[i * width + j];
		}
	}
	//fill canvas rows
	for (i = 0; i < sW/2; i++)
	{
		for (j = 0; j < width; j++)
		{
			//images
			imCanvasStripN[i * cnv_width + (j + sW/2)] = i_imNoisy[i * width + j];
			imCanvasStripN[(cnv_height - i - 1) * cnv_width + (j + sW/2)] = i_imNoisy[(height - i - 1) * width + j];
			imCanvasStripG[i * cnv_width + (j + sW/2)] = i_imGuide[i * width + j];
			imCanvasStripG[(cnv_height - i - 1) * cnv_width + (j + sW/2)] = i_imGuide[(height - i - 1) * width + j];
			//coeff
			aStrip[i * cnv_width + (j + sW/2)] = 0.5;
			aStrip[(cnv_height - i - 1) * cnv_width + (j + sW/2)] = 0.5;
			bStrip[i * cnv_width + (j + sW/2)] = (float)0x0fff;
			bStrip[(cnv_height - i - 1) * cnv_width + (j + sW/2)] = (float)0x0fff;
		}
	}
	//fill canvas columns
	for (i = 0; i < height; i++)
	{
		for (j = 0; j <= sW/2; j++)
		{
			//images
			imCanvasStripN[(i + sW/2) * cnv_width + j] = i_imNoisy[i * width + j];
			imCanvasStripN[(i + sW/2) * cnv_width + (cnv_width - j - 1)] = i_imNoisy[i * width + (width - j - 1)];
			imCanvasStripG[(i + sW/2) * cnv_width + j] = i_imGuide[i * width + j];
			imCanvasStripG[(i + sW/2) * cnv_width + (cnv_width - j - 1)] = i_imGuide[i * width + (width - j - 1)];
			//coeff
			aStrip[(i + sW/2) * cnv_width + j] = 0.5;
			aStrip[(i + sW/2) * cnv_width + (cnv_width - j - 1)] = 0.5;
			bStrip[(i + sW/2) * cnv_width + j] = (float)0x0fff;
			bStrip[(i + sW/2) * cnv_width + (cnv_width - j - 1)] = (float)0x0fff;
		}
	}


#ifdef _OPENMP
	omp_set_num_threads(nThreads);
	#pragma omp parallel for private(muN, muG, sigmaGN, sigmaGG, n, m, j)
#endif
	for (i = sW/2; i < cnv_height - sW/2; i++) 
	{
		for (j = sW/2; j < cnv_width - sW/2; j++)
		{
			//estimate mu
			muN = 0.0;
			muG = 0.0;
			for (n = -delta_v; n <= delta_v; n++)
			{
				for (m = -delta_h; m <= delta_h; m++)
				{
					muN += (double)imCanvasStripN[(i + n) * cnv_width + (j + m)];
					muG += (double)imCanvasStripG[(i + n) * cnv_width + (j + m)];
				}
			}
			muN /= sW;	
			muG /= sW;

			//estimate sigma
			sigmaGN = 0.0;
			sigmaGG = 0.0;
			for (n = -delta_v; n <= delta_v; n++)
			{
				for (m = -delta_h; m <= delta_h; m++)
				{
					sigmaGN += (double)imCanvasStripN[(i + n) * cnv_width + (j + m)] * (double)imCanvasStripG[(i + n) * cnv_width + (j + m)];
					sigmaGG += ((double)imCanvasStripG[(i + n) * cnv_width + (j + m )] - muG) * ((double)imCanvasStripG[(i + n) * cnv_width + (j + m)] - muG);
				}
			}
			sigmaGN = sigmaGN / sW - muN * muG;
			sigmaGG /= sW;

			//estimate a and b coeff
			aStrip[i * cnv_width + j] = (sigmaGN) / (sigmaGG + eps);
			bStrip[i * cnv_width + j] = muG - aStrip[i * cnv_width + j] * muN;
		}
	}


#ifdef _OPENMP
	omp_set_num_threads(nThreads);
	#pragma omp parallel for private (sum_a, sum_b, out_img, n, m, j)
#endif
	for (i = 0; i < height; i++) 
	{
		for (j = 0; j < width; j++)
		{
			//estimate mean a/b coeff in (1 x sW) area
			sum_a = 0.0;
			sum_b = 0.0;
			for (n = -delta_v; n <= delta_v; n++)
			{
				for (m = -delta_h; m <= delta_h; m++)
				{			
					sum_a += aStrip[(i + n + sW/2) * cnv_width + (j + m + sW/2)];
					sum_b += bStrip[(i + n + sW/2) * cnv_width + (j + m + sW/2)];
				}
			}
			sum_a /= sW;
			sum_b /= sW;

			out_img = (Int16)((double)i_imGuide[i * width + j] * sum_a + sum_b);
			o_imSmooth[i * width + j] = out_img;
			o_imTexture[i * width + j] = i_imNoisy[i * width + j] - out_img;
		}
	} 

#ifndef STATIC_ARRAYS
	free(imCanvasStripG);
	free(imCanvasStripN);
	free(aStrip);
	free(bStrip);
#endif
}


//Guided image filter, guided img = input img (for DDE filter)
void runGIFfilter(uInt16 *i_imNoisy, Int16 *o_imBase, float *o_aGIF, AgcParams *p_params, ImgSize *p_size)
{
	int i, j, m, n;
	unsigned int sW = p_params->sizeW;
	unsigned int width = p_size->width;
	unsigned int height = p_size->height;
	unsigned int k_max = p_size->n_valid;
	double eps = p_params->eps;
	//size of canvas image
	unsigned int cnv_width = width + (sW >> 1) * 2;
	unsigned int cnv_height = height + (sW >> 1) * 2;
	double mu, sigma;
	double sum_a, sum_b;

#ifndef STATIC_ARRAYS
	Int16 *imCanvasDDE = (Int16 *)malloc(sizeof(Int16) * cnv_width * cnv_height);
	float *aDDE = (float *)malloc(sizeof(float) * cnv_width * cnv_height);
	float *bDDE = (float *)malloc(sizeof(float) * cnv_width * cnv_height);
#endif

#ifdef _OPENMP
	omp_set_num_threads(nThreads);
	#pragma omp parallel for private(j)
#endif
	for (i = 0; i < height; i++)
	{
		for (j = 0; j < width; j++)
		{
			imCanvasDDE[(i + sW/2) * cnv_width + (j + sW/2)] = i_imNoisy[i * width + j];
		} 
	}
	//fill canvas rows
	for (i = 0; i < sW/2; i++)
	{
		for (j = 0; j < width; j++)
		{
			imCanvasDDE[i * cnv_width + (j + sW/2)] = i_imNoisy[i * width + j];
			imCanvasDDE[(cnv_height - i - 1) * cnv_width + (j + sW/2)] = i_imNoisy[(height - i - 1) * width + j];

			aDDE[i * cnv_width + (j + sW/2)] = 0.5;
			aDDE[(cnv_height - i - 1) * cnv_width + j] = 0.5;
			bDDE[i * cnv_width + (j + sW/2)] = (float)0x0fff;
			bDDE[(cnv_height - i - 1) * cnv_width + (j + sW/2)] = (float)0x0fff;
		}
	}
	//fill canvas columns
	for (i = 0; i < height; i++)
	{
		for (j = 0; j <= sW/2; j++)
		{
			imCanvasDDE[(i + sW/2) * cnv_width + j] = i_imNoisy[i * width + j];
			imCanvasDDE[(i + sW/2) * cnv_width + (cnv_width - j - 1)] = i_imNoisy[i * width + (width - j - 1)];
			
			aDDE[(i + sW/2) * cnv_width + j] = 0.5;
			aDDE[(i + sW/2) * cnv_width + (cnv_width - j - 1)] = 0.5;
			bDDE[(i + sW/2) * cnv_width + j] = (float)0x0fff;
			bDDE[(i + sW/2) * cnv_width + (cnv_width - j - 1)] = (float)0x0fff;
		}
	}

#ifdef _OPENMP
	omp_set_num_threads(nThreads);
	#pragma omp parallel for private(sigma, mu, n, m, j)
#endif
	//estimate a and b coeff arrays
	for (i = sW/2; i < cnv_height - sW/2; i++) 
	{
		for (j = sW/2; j < cnv_width - sW/2; j++)
		{
			//estimate mu
			mu = 0.0;
			for (n = -sW/2; n <= sW/2; n++)
			{
				for (m = -sW/2; m <= sW/2; m++)
				{
					mu += (double)imCanvasDDE[(i + n) * cnv_width + (j + m)];
				}
			}
			mu /= sW * sW;	

			//estimate sigma
			sigma = 0.0;
			for (n = -sW/2; n <= sW/2; n++)
			{
				for (m = -sW/2; m <= sW/2; m++)
				{			
					sigma += ((double)imCanvasDDE[(i + n) * cnv_width + (j + m)] - mu) * ((double)imCanvasDDE[(i + n) * cnv_width + (j + m)] - mu);
				}
			}

			sigma /= sW * sW;
			//estimate a and b coeff
			aDDE[i * width + j] = (float)(sigma / (sigma + eps));
			bDDE[i * width + j] = (1 - aDDE[i * width + j]) * mu;
		}
	}

#ifdef _OPENMP
	omp_set_num_threads(nThreads);
	#pragma omp parallel for private (sum_a, sum_b, n, m, j)
#endif
	//estimate smooth image
	for (i = 0; i < height; i++) 
	{
		for (j = 0; j < width; j++)
		{
			//estimate mean a/b coeff in (sW x sW) area
			sum_a = 0.0;
			sum_b = 0.0;
			for (n = -sW/2; n <= sW/2; n++)
			{
				for (m = -sW/2; m <= sW/2; m++)
				{			
					sum_a += aDDE[(i + n + sW/2) * width + (j + m + sW/2)];
					sum_b += bDDE[(i + n + sW/2) * width + (j + m + sW/2)];
				}
			}
			sum_a /= sW * sW;
			sum_b /= sW * sW;

			o_imBase[i * width + j] = imCanvasDDE[(i + sW/2) * cnv_width + (j + sW/2)];
			o_aGIF[i * width + j] = aDDE[(i + sW/2) * cnv_width + (j + sW/2)];
		}
	} 
#ifndef STATIC_ARRAYS
	free(imCanvasDDE);
	free(aDDE);
	free(bDDE);
#endif
}


void runHistProtection(Int16 *i_imBase, Int16 *o_imBaseP, AgcParams *p_params, ImgSize *p_size)
{
	int i;
	long int sum_hist = 0;
	//max value of each pixel (0x3fff)
	uInt16 n_valid = p_size->n_valid;
	int width = p_size->width;
	int height = p_size->height;
	uInt16 indexM = 0;
	//T = N_pix / n_valid = 18 for 640x512 image
	unsigned int T = p_params->T;
	int hist_max;

	//histogram	array
#ifndef STATIC_ARRAYS
	int *hist = (int *)malloc(sizeof(int) * n_valid);
	int *histSum = (int *)malloc(sizeof(int) * n_valid);
#endif

#ifdef _OPENMP
	omp_set_num_threads(nThreads);
	#pragma omp parallel for
#endif
	for (i = 0; i < n_valid; i++)
	{
		hist[i] = 0;
	}

	//build histogram
	for (i = 0; i < width * height; i++)
	{
		indexM = i_imBase[i]; 
		hist[indexM]++;
	}

	//build cumulative sum of histogram
	for (i = 0; i < n_valid; i++)
	{
		sum_hist += (hist[i] > T) ? 1 : 0;
		histSum[i] = sum_hist;
	}

	hist_max = histSum[n_valid-1];

#ifdef _OPENMP
	omp_set_num_threads(nThreads);
	#pragma omp parallel for
#endif
	for (i = 0; i < n_valid; i++)
	{
		histSum[i] = histSum[i] * n_valid / hist_max;
	}


#ifdef _OPENMP
	omp_set_num_threads(nThreads);
	#pragma omp parallel for
#endif
	//estimate cumulative distribution of binarized histogram D(X, T)
	for (i = 0; i < width * height; i++)
	{
		o_imBaseP[i] = histSum[i_imBase[i]];
	}
#ifndef STATIC_ARRAYS
	free(hist);
	free(histSum);
#endif
}


void runGainMaskEnhancement(Int16 *i_imDetail, Int16 *o_imDetailP, float *i_a1, float *i_a2, AgcParams *p_params, ImgSize *p_size)
{
	int i;
	int width = p_size->width;
	int height = p_size->height;
	int n_valid = p_size->n_valid;
	int max_detail = p_params->max_detail;
	float delta, temp_ma, temp_fp;

	float max_ma = 0.0;
	float min_ma = 1.0;

	Int16 max_im = -0x3fff;
	Int16 min_im = 0x3fff;
	float m1 = 0.0;
	float m2 = 0.0;
	float s1 = 0.0;
	float s2 = 0.0;

	//matrix Ma_ij = a1_ij * a2_ij
#ifndef STATIC_ARRAYS
	float *Ma = (float *)malloc(sizeof(float) * p_size->width * p_size->height);
#endif

	//estimate Ma and means m1/m2
#ifdef _OPENMP
	omp_set_num_threads(nThreads);
	#pragma omp parallel for reduction(+:m1, m2)
#endif
	for (i = 0; i < width * height; i++)
	{
		Ma[i] = i_a1[i] * i_a2[i];
		m1 += i_a1[i];
		m2 += i_a2[i];
	}
	m1 /= (float)(width * height);
	m2 /= (float)(width * height);

	//estimate sto s1/s2
#ifdef _OPENMP
	omp_set_num_threads(nThreads);
	#pragma omp parallel for reduction(+:s1, s2) shared(m1, m2)
#endif
	for (i = 0; i < width * height; i++)
	{
		s1 += (i_a1[i] - m1) * (i_a1[i] - m1);
		s2 += (i_a2[i] - m2) * (i_a2[i] - m2);
	}
	
	s1 = sqrt(s1 / (float)(width * height));
	s2 = sqrt(s2 / (float)(width * height));

	delta = m2 * ( 1 + (m2 + s2) / (m1 + s1));

	for (i=0; i < width * height; i++)
	{
		temp_ma = i_a1[i] * i_a2[i];
		Ma[i] =  (temp_ma < delta) ? temp_ma : delta;

		//max/min of Ma
		max_ma = (temp_ma > max_ma) ? temp_ma : max_ma;
		min_ma = (temp_ma < min_ma) ? temp_ma : min_ma;
		//max/min
		max_im = (i_imDetail[i] > max_im) ? i_imDetail[i] : max_im;
		min_im = (i_imDetail[i] < min_im) ? i_imDetail[i] : min_im;
	}

#ifdef _OPENMP
	omp_set_num_threads(nThreads);
	#pragma omp parallel for private(temp_ma, temp_fp) shared(max_ma, min_ma, max_im, min_im)
#endif
	for (i = 0; i < width * height; i++)
	{
		temp_ma = (Ma[i] - min_ma) / (max_ma - min_ma);
		temp_fp = (float)(i_imDetail[i] - min_im) / (float)(max_im - min_im) * (float)(max_detail) * temp_ma;
		o_imDetailP[i] = (Int16)temp_fp;
	}
#ifndef STATIC_ARRAYS
	free(Ma);
#endif
}


////////////////////////////////////////
//Element-wise addition and subtraction
void addImage(Int16 *i_imFirst, Int16 *i_imSecond, Int16 *o_imResult, ImgSize *p_size)
{
	int i;
	int width = p_size->width;
	int height = p_size->height;

#ifdef _OPENMP
	omp_set_num_threads(nThreads);
	#pragma omp parallel for
#endif
	for (i = 0; i < width * height; i++)
	{
		o_imResult[i] = i_imFirst[i] + i_imSecond[i];
	}	

}


void subImage(Int16 *i_imFirst, Int16 *i_imSecond, Int16 *o_imResult, ImgSize *p_size)
{
	int i;
	int width = p_size->width;
	int height = p_size->height;

#ifdef _OPENMP
	omp_set_num_threads(nThreads);
	#pragma omp parallel for
#endif
	for (i = 0; i < width * height; i++)
	{
		o_imResult[i] = i_imFirst[i] - i_imSecond[i];
	}	
}


void copyImage(uInt16 *i_imFirst, Int16 *i_imSecond, ImgSize *p_size)
{
	int i;
	Int16 temp;
	int width = p_size->width;
	int height = p_size->height;
	Int16 max_k = p_size->n_valid;

#ifdef _OPENMP
	omp_set_num_threads(nThreads);
	#pragma omp parallel for private(temp) shared(max_k)
#endif
	for (i = 0; i < width * height; i++)
	{
		temp = i_imSecond[i];
		i_imFirst[i] = (uInt16)((temp > max_k) ? max_k : (temp < 0) ? 0 : temp);
	}	
}


//add test strip noise to image
void addStrip(uInt16 *io_imNoisy, unsigned int delta, unsigned int strip_width, ImgSize *p_size)
{
	int i, j;
	uInt16 temp;
	int width = p_size->width;
	int height = p_size->height;
	uInt16 max_k = p_size->n_valid;

	#ifdef _OPENMP
	omp_set_num_threads(nThreads);
	#pragma omp parallel for private(temp, j) shared(max_k, strip_width, delta)
#endif
	for (i = 0; i < height; i++)
	{
		for (j=0; j < width; j++)
		{
		temp = io_imNoisy[i * width + j] + delta * (j % strip_width) / strip_width;
		io_imNoisy[i * width + j] = (uInt16)((temp > max_k) ? max_k : (temp < 0) ? 0 : temp);
		}
	}
}