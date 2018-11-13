//Display and detail enhancement for high-dynamic-range infrared images
//https://www.researchgate.net/publication/258338485_Display_and_detail_enhancement_for_high-dynamic-range_infrared_images
//https://www.researchgate.net/publication/236228168_Guided_Image_Filtering

#ifndef _DDE_GUIDED_FILTER_H_
#define _DDE_GUIDED_FILTER_H_

//#undef _OPENMP
#define STATIC_ARRAYS

//max value of pixel
#define MAX_VALID				0x3fff
//size of hist and img arrays
#ifdef STATIC_ARRAYS
#define IMG_WIDTH				640
#define IMG_HEIGHT				512
#define IMG_SIZE				(IMG_WIDTH * IMG_HEIGHT)
//temp canvas image
#define DDE_CANVAS				3
#define STRIP_CANVAS			5
#define IMG_CANVAS_DDE_SIZE		((IMG_WIDTH + (DDE_CANVAS >> 1) * 2) * (IMG_HEIGHT + (DDE_CANVAS >> 1) * 2))
#define IMG_CANVAS_STRIP_SIZE	((IMG_WIDTH + (STRIP_CANVAS >> 1) * 2) * (IMG_HEIGHT + (STRIP_CANVAS >> 1) * 2))
#endif

#include <stdio.h>
#include <math.h>
#include "niimaq.h"
#include <malloc.h>
#ifdef _OPENMP
#include <omp.h>
#endif

//static arrays
#ifdef STATIC_ARRAYS
//DDEfilter function
static Int16 imCanvasDDE[IMG_CANVAS_DDE_SIZE];
//Temp arrays with canvas
static float aDDE[IMG_CANVAS_DDE_SIZE];
static float bDDE[IMG_CANVAS_DDE_SIZE];
//Temp arrays of coeffs
static float a1GIF[IMG_SIZE];
static float a2GIF[IMG_SIZE];
static float Ma[IMG_SIZE];
// Temp images of DDE
static Int16 imBase1[IMG_SIZE];
static Int16 imBase2[IMG_SIZE];
static Int16 imBaseP[IMG_SIZE];
static Int16 imDetail[IMG_SIZE];
static Int16 imDetailP[IMG_SIZE];
static Int16 imFinal[IMG_SIZE];
//GIF filter
static Int16 imCanvasStripN[IMG_CANVAS_STRIP_SIZE];
static Int16 imCanvasStripG[IMG_CANVAS_STRIP_SIZE];
static float aStrip[IMG_CANVAS_STRIP_SIZE];
static float bStrip[IMG_CANVAS_STRIP_SIZE];
//hist protection
static int hist[MAX_VALID]; 
static int histSum[MAX_VALID];
//gain mask enhancement
static float MaGIF[IMG_SIZE];
//DDEstrip removal
static Int16 imSmooth[IMG_SIZE]; 
static Int16 imTextureN[IMG_SIZE]; 
static Int16 imStrip[IMG_SIZE];
static Int16 imTexture[IMG_SIZE];
static Int16 imTemp[IMG_SIZE];
#endif

#ifdef __cplusplus
extern "C"
{
#endif

//threads of OpenMP
static int nThreads = 4;//omp_get_max_threads();
//direct of GIF filtering (row/column with size (1, sW))
enum direct_t {horizontal, vertical};

typedef struct StripParams_t {
	unsigned int sizeW;
	double eps;
	enum direct_t direct;
} StripParams;

typedef struct AgcParams_t {
	unsigned int sizeW;
	double eps;
	double eps_div;
	unsigned int max_detail;
	unsigned int T;
} AgcParams;

 typedef struct ImgSize_t {
	unsigned int width;
	unsigned int height;
	unsigned int n_valid;
} ImgSize;


//init filter params and image size
void initStripParams(StripParams *io_params, unsigned int sizeW, float eps);
void initAgcParams(AgcParams *io_params, unsigned int sW, unsigned int max_detail, float eps, float eps_div, unsigned int T);
void initSizeParams(ImgSize *io_size, int width, int height, int nBits);
//strip noise removal
void runStripfilter(uInt16 *io_imNoisy, StripParams *p_params, ImgSize *p_size);
void runGIFstrip(uInt16 *i_imNoisy, uInt16 *i_imGuide, Int16 *o_imSmooth, Int16 *o_imTexture, StripParams *p_params, ImgSize *p_size);
//algorithm (Agc + Guided Image Filter (GIF))
void runDDEfilter(uInt16 *io_imNoisy, AgcParams *io_params, ImgSize *io_size);
void runGIFfilter(uInt16 *i_imNoisy, Int16 *o_imBase, float *o_wKernel, AgcParams *p_params, ImgSize *p_size);
void runHistProtection(Int16 *i_imBase, Int16 *o_imBaseP, AgcParams *p_params, ImgSize *p_size);
void runGainMaskEnhancement(Int16 *i_imDetail, Int16 *o_imDetailP, float *i_a1, float *i_a2, AgcParams *p_params, ImgSize *p_size);
//element-wise addition and subtraction
void addImage(Int16 *i_imFirst, Int16 *i_imSecond, Int16 *o_imResult, ImgSize *p_size);
void subImage(Int16 *i_imFirst, Int16 *i_imSecond, Int16 *o_imResult, ImgSize *p_size);
void copyImage(uInt16 *i_imFirst, Int16 *i_imSecond, ImgSize *p_size);
//add test strip noise to image
void addStrip(uInt16 *io_imNoisy, unsigned int delta, unsigned int strip_width, ImgSize *p_size);

#ifdef __cplusplus
}
#endif

#endif
