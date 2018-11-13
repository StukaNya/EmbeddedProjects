
#ifndef HAWK_PROCESSING_H
#define HAWK_PROCESSING_H

//#undef _OPENMP
#define STATIC_ARRAYS

//max value of pixel
#define MAX_VALID				0x3fff
//size of hist and img arrays
#define IMG_WIDTH				640
#define IMG_HEIGHT				512
#define IMG_SIZE				(IMG_WIDTH * IMG_HEIGHT)
//temp canvas image
#define DDE_CANVAS				7
#define STRIP_CANVAS			9
#define IMG_CANVAS_DDE_SIZE		((IMG_WIDTH + (DDE_CANVAS >> 1) * 2) * (IMG_HEIGHT + (DDE_CANVAS >> 1) * 2))
#define IMG_CANVAS_STRIP_SIZE	((IMG_WIDTH + (STRIP_CANVAS >> 1) * 2) * (IMG_HEIGHT + (STRIP_CANVAS >> 1) * 2))


#include <QObject>
#include <QString>
#include <QVector>
#include <QSignalMapper>
#include <stdio.h>
#include <math.h>
#include <malloc.h>
#ifdef _OPENMP
#include <omp.h>
#endif
#include "fftFilt.h"

class HawkProcessing : public QObject
{
    Q_OBJECT
public:
    static HawkProcessing* Instance() {
        if (I == NULL) { I = new HawkProcessing(); }
        return I;
    }
    //threads of OpenMP
#ifdef _OPENMP
    int nThreads = omp_get_max_threads();
#else
    int nThreads = 1;
#endif
    //direct of GIF filtering (row/column with size (1, sW))
    enum direct_t {horizontal, vertical};

    typedef struct ProcParams_t {
        bool dde;
        bool strip;
        bool pt2_calib;
        bool pt2_pt1;
        bool pt4_calib;
        bool pt4_pt2;
        bool blow_out;
        bool frame_avg;
        bool pos_neg;
        bool zoom_2x;
    } ProcParams;

    typedef struct StripParams_t {
        unsigned int sizeW;
        double eps;
        unsigned int Ts;
        enum direct_t direct;
    } StripParams;

    typedef struct AgcParams_t {
        unsigned int sizeW;
        double eps1;
        double eps2;
        unsigned int max_detail;
        unsigned int hist_bord;
        int algo_step;
    } AgcParams;

     typedef struct ImgSize_t {
        unsigned int width;
        unsigned int height;
        unsigned int n_valid;
    } ImgSize;

    typedef struct  fftParams_t {
        bool lineFFT;
        bool frameFFT;
        int numLine;
    } fftParams;

    static ProcParams ProcP;
    static AgcParams AgcP;
    static StripParams StripP;
    static ImgSize ImgSz;
    static fftParams fftP;

    void runHawkProcessing(ushort *io_imNoisy);
    void initValues();

private:
    explicit HawkProcessing(QObject *parent = 0);
    ~HawkProcessing() {}
    //disable copy-constructor and assignment
    HawkProcessing(const HawkProcessing &);
    HawkProcessing& operator=(const HawkProcessing);
    // pointer on singleton instance
    static HawkProcessing *I;
    // DDE/Strip Filters
    //strip noise removal
    void runStripfilter(ushort *io_imNoisy);
    void runGIFstrip();
    //algorithm (Agc + Guided Image Filter (GIF))
    void runDDEfilter(ushort *io_imNoisy);
    void runGIFfilter();
    void runHistProtection();
    void runGainMaskEnhancement();
    //element-wise addition and subtraction
    void addBaseImage();
    void subBaseImage();
    void subStripImage();
    void copyInputImage(ushort *i_imNoisy);
    void copyOutputImage(ushort *o_imFinal);
    //Other filters
    //FilterFrameAveraging
    void runFrameAveraging(ushort *io_img);
    void runBlowOut(ushort *img);
    void runZoom2x(ushort *io_img);
    void runPosNeg(ushort *io_img);
    //2PT calibration
    bool frameSumming(ushort *io_img);
    bool prepCor2PT(ushort *io_img);
    void calibImg2PT(ushort *io_img);
    //4PT Calibration
    void initTable4PT();
    void prepCor4PT(ushort *io_img);
    void calibImg4PT(ushort *io_img);
    //FFT
    void runLineFFT(ushort *io_img);
    void runFrameFFT(ushort *io_img);
    //number of frames
    static long int cntPTFrame;
    //input image
    static short imNoisy[IMG_SIZE];
    //DDEfilter function
    static short imCanvasDDE[IMG_CANVAS_DDE_SIZE];
    //Temp arrays with canvas
    static float aDDE[IMG_CANVAS_DDE_SIZE];
    static float bDDE[IMG_CANVAS_DDE_SIZE];
    //Temp arrays of coeffs
    static float a1GIF[IMG_SIZE];
    static float a2GIF[IMG_SIZE];
    static float MaGIF[IMG_SIZE];
    // Temp images of DDE
    static short imBase1[IMG_SIZE];
    static short imBase2[IMG_SIZE];
    static short imBaseP[IMG_SIZE];
    static short imDetail[IMG_SIZE];
    static short imDetailP[IMG_SIZE];
    static short imFinal[IMG_SIZE];
    //GIF filter
    static short imCanvasStripN[IMG_CANVAS_STRIP_SIZE];
    static short imCanvasStripG[IMG_CANVAS_STRIP_SIZE];
    static float aStrip[IMG_CANVAS_STRIP_SIZE];
    static float bStrip[IMG_CANVAS_STRIP_SIZE];
    //hist protection
    static int hist[MAX_VALID];
    static int histSum[MAX_VALID];
    //DDEstrip removal
    static short imSmooth[IMG_SIZE];
    static short imTextureN[IMG_SIZE];
    static short imStrip[IMG_SIZE];
    static short imTexture[IMG_SIZE];
    //Buffer for FilterFrameAveraging
    static ushort imOld[IMG_SIZE];
    //buffer for zoom2x
    static ushort bufrez[IMG_SIZE / 4];
    //buffer for 2PT calib
    static uint   SumKoefBuff[IMG_SIZE];
    static ushort KoefBuff[IMG_SIZE];
    static ushort Kc[IMG_SIZE];
    static float  addImg[IMG_SIZE];
    //buffer for 4PT calib
    static float a_e;
    static float b_e;
    static float c_e;
    static float d_e;
    static float e_e;
    static float a_i[IMG_SIZE];
    static float b_i[IMG_SIZE];
    static float c_i[IMG_SIZE];
    static float d_i[IMG_SIZE];
    static float e_i[IMG_SIZE];

signals:
    void sendAgcParams(int id, QString message);
    void sendStripParams(int id, QString message);
    void sendProcParams(int id, bool state);
    void onPlotLineFFT(QVector<double> data, uint width);
    void onPlotFrameFFT(QVector<double> data, uint width, uint height);
public slots:
    void updateProcParams(int id, bool state);
    void updateAgcParams(int id, QString message);
    void updateStripParams(int id, QString message);
    void hawkRunFFT(int id, int n_line);
};

#endif // HAWK_PROCESSING_H
