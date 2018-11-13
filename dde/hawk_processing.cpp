#include "hawk_processing.h"
#include "koefMult.h"
#undef _OPENMP

HawkProcessing * HawkProcessing::I = NULL;

HawkProcessing::ProcParams  HawkProcessing::ProcP;
HawkProcessing::AgcParams   HawkProcessing::AgcP;
HawkProcessing::StripParams HawkProcessing::StripP;
HawkProcessing::ImgSize     HawkProcessing::ImgSz;
HawkProcessing::fftParams   HawkProcessing::fftP;

long int HawkProcessing::cntPTFrame;

short  HawkProcessing::imNoisy[IMG_SIZE];
short  HawkProcessing::imCanvasDDE[IMG_CANVAS_DDE_SIZE];
float  HawkProcessing::aDDE[IMG_CANVAS_DDE_SIZE];
float  HawkProcessing::bDDE[IMG_CANVAS_DDE_SIZE];
float  HawkProcessing::a1GIF[IMG_SIZE];
float  HawkProcessing::a2GIF[IMG_SIZE];
float  HawkProcessing::MaGIF[IMG_SIZE];
short  HawkProcessing::imBase1[IMG_SIZE];
short  HawkProcessing::imBase2[IMG_SIZE];
short  HawkProcessing::imBaseP[IMG_SIZE];
short  HawkProcessing::imDetail[IMG_SIZE];
short  HawkProcessing::imDetailP[IMG_SIZE];
short  HawkProcessing::imFinal[IMG_SIZE];
short  HawkProcessing::imCanvasStripN[IMG_CANVAS_STRIP_SIZE];
short  HawkProcessing::imCanvasStripG[IMG_CANVAS_STRIP_SIZE];
float  HawkProcessing::aStrip[IMG_CANVAS_STRIP_SIZE];
float  HawkProcessing::bStrip[IMG_CANVAS_STRIP_SIZE];
int    HawkProcessing::hist[MAX_VALID];
int    HawkProcessing::histSum[MAX_VALID];
short  HawkProcessing::imSmooth[IMG_SIZE];
short  HawkProcessing::imTextureN[IMG_SIZE];
short  HawkProcessing::imStrip[IMG_SIZE];
short  HawkProcessing::imTexture[IMG_SIZE];
ushort HawkProcessing::imOld[IMG_SIZE];
ushort HawkProcessing::bufrez[IMG_SIZE / 4];
ushort HawkProcessing::KoefBuff[IMG_SIZE];
uint   HawkProcessing::SumKoefBuff[IMG_SIZE];
ushort HawkProcessing::Kc[IMG_SIZE];
float  HawkProcessing::addImg[IMG_SIZE];
float  HawkProcessing::a_e;
float  HawkProcessing::b_e;
float  HawkProcessing::c_e;
float  HawkProcessing::d_e;
float  HawkProcessing::e_e;
float  HawkProcessing::a_i[IMG_SIZE];
float  HawkProcessing::b_i[IMG_SIZE];
float  HawkProcessing::c_i[IMG_SIZE];
float  HawkProcessing::d_i[IMG_SIZE];
float  HawkProcessing::e_i[IMG_SIZE];

HawkProcessing::HawkProcessing(QObject *parent) : QObject(parent)
{
    cntPTFrame = 0;

    ImgSz.width = IMG_WIDTH;
    ImgSz.height = IMG_HEIGHT;
    ImgSz.n_valid = MAX_VALID;

    AgcP.sizeW = 3;
    AgcP.eps1 = 2500.0;
    AgcP.eps2 = 250.0;
    AgcP.max_detail = 512;
    AgcP.hist_bord = 20;
    AgcP.algo_step = 1;

    StripP.sizeW = 7;
    StripP.eps = 250.0;
    StripP.Ts = 20.0;

    ProcP.dde         = false;
    ProcP.strip       = false;
    ProcP.pt2_calib   = false;
    ProcP.pt2_pt1     = false;
    ProcP.pt4_calib   = false;
    ProcP.pt4_pt2     = false;
    ProcP.blow_out    = false;
    ProcP.frame_avg   = false;
    ProcP.pos_neg     = false;
    ProcP.zoom_2x     = false;
    fftP.lineFFT      = false;
    fftP.frameFFT     = false;

    memcpy(Kc, koefMult, IMG_SIZE*2);
    initTable4PT();
}


//set lineEdit/checkBox values
void HawkProcessing::initValues()
{
    emit sendAgcParams(0, QString::number(AgcP.sizeW));
    emit sendAgcParams(1, QString::number((double)AgcP.eps1, 'f', 1));
    emit sendAgcParams(2, QString::number((double)AgcP.eps2,  'f', 1));
    emit sendAgcParams(3, QString::number(AgcP.max_detail));
    emit sendAgcParams(4, QString::number(AgcP.hist_bord));

    emit sendStripParams(0, QString::number(StripP.sizeW));
    emit sendStripParams(1, QString::number((double)StripP.eps, 'f', 1));
    emit sendStripParams(2, QString::number((double)StripP.Ts, 'f', 1));

    emit sendProcParams(0, ProcP.dde      );
    emit sendProcParams(1, ProcP.strip    );
    emit sendProcParams(2, ProcP.pt2_calib);
    emit sendProcParams(3, ProcP.pt2_pt1  );
    emit sendProcParams(4, ProcP.pt4_calib);
    emit sendProcParams(5, ProcP.pt4_pt2  );
    emit sendProcParams(6, ProcP.blow_out );
    emit sendProcParams(7, ProcP.frame_avg);
    emit sendProcParams(8, ProcP.pos_neg  );
    emit sendProcParams(9, ProcP.zoom_2x  );
}


//main algo procedure
void HawkProcessing::runHawkProcessing(ushort *io_imNoisy)
{
    if (ProcP.frame_avg)
        runFrameAveraging(io_imNoisy);
    if (ProcP.pt2_pt1) {
        cntPTFrame++;
        if (frameSumming(io_imNoisy)) {
            prepCor2PT(io_imNoisy);
            cntPTFrame = 0;
        }
    }
    if (ProcP.pt2_calib)
        calibImg2PT(io_imNoisy);
    if (ProcP.pt4_pt2)
        cntPTFrame++;
        if (frameSumming(io_imNoisy)) {
            prepCor4PT(io_imNoisy);
            cntPTFrame = 0;
        }
    if (ProcP.pt4_calib)
        calibImg4PT(io_imNoisy);
    if (ProcP.strip)
        runStripfilter(io_imNoisy);
    if (ProcP.dde)
        runDDEfilter(io_imNoisy);
    if (ProcP.blow_out)
        runBlowOut(io_imNoisy);
    if (ProcP.zoom_2x)
        runZoom2x(io_imNoisy);
    if (ProcP.pos_neg)
        runPosNeg(io_imNoisy);

    if (fftP.lineFFT) {
        runLineFFT(io_imNoisy);
        fftP.lineFFT = false;
    }
    if (fftP.frameFFT) {
        runFrameFFT(io_imNoisy);
        fftP.frameFFT = false;
    }
}


/////////////////////////////////////////////
//algorithm (Agc + Guided Image Filter (GIF))
void HawkProcessing::runDDEfilter(ushort *io_imNoisy)
{
    //io_imNoisy -> imNoisy
    copyInputImage(io_imNoisy);
    //imNoisy -> imBase1
    AgcP.algo_step = 1;
    runGIFfilter();
    //imNoisy -> imBase2
    AgcP.algo_step = 2;
    runGIFfilter();
    //imBase2 ->imBaseP
    runHistProtection();
    //imDetail = imBase2 - imBase1
    subBaseImage();
    //imDetail -> imDetailP
    runGainMaskEnhancement();
    //imFinal = imBaseP + imDetailP
    addBaseImage();
    //imFinal -> io_imNoisy
    copyOutputImage(io_imNoisy);
}


/////////////////////////////////////////////
//Strip Noise Removal
void HawkProcessing::runStripfilter(ushort *io_imNoisy)
{
    //io_imNoisy -> imNoisy
    copyInputImage(io_imNoisy);
    //1D row guided filter
    //imNoisy -> imSmooth + imTextureN (Texture + Strip)
    StripP.direct = horizontal;
    runGIFstrip();
    //1D column guided filter
    //imTextureN -> imStrip + imTexture
    StripP.direct = vertical;
    runGIFstrip();
    //Subtract strips from Noisy image
    //imFinal = imNoisy - imStrip
    subStripImage();
    //imFinal -> io_imNoisy
    copyOutputImage(io_imNoisy);
}

//Guided image filter, guided img != input img (for Strip Noise Removal)
void HawkProcessing::runGIFstrip()
{
    int width = ImgSz.width;
    unsigned int height = ImgSz.height;
    unsigned int sW = StripP.sizeW;
    double eps = StripP.eps;
    enum direct_t direct = StripP.direct;
    //input images
    short *pGuide = (StripP.direct == horizontal) ? &imNoisy[0] : &imTextureN[0];
    short *pSmooth = (StripP.direct == horizontal) ? &imSmooth[0] : &imStrip[0];
    short *pTexture = (StripP.direct == horizontal) ? &imTextureN[0] : &imTexture[0];
    //size of canvas image
    unsigned int cnv_width = width + (sW >> 1) * 2;
    unsigned int cnv_height = height + (sW >> 1) * 2;

    int i, j, m, n;
    short out_img;
    double muN, sigmaGN, muG, sigmaGG;
    double sum_a, sum_b;
    //set border for loop
    //delta_h - horizontal, delta_v - vertical
    int delta_h = (direct == horizontal) ? sW / 2 : 0;
    int delta_v = (direct == vertical) ? sW / 2 : 0;

#ifdef _OPENMP
    omp_set_num_threads(nThreads);
    #pragma omp parallel for private(j)
#endif
    for (i = 0; i < height; i++)
    {
        for (j = 0; j < width; j++)
        {
            imCanvasStripN[(i + sW/2) * cnv_width + (j + sW/2)] = pGuide[i * width + j];
            imCanvasStripG[(i + sW/2) * cnv_width + (j + sW/2)] = pGuide[i * width + j];
        }
    }
    //fill canvas rows
    for (i = 0; i < sW/2; i++)
    {
        for (j = 0; j < width; j++)
        {
            //images
            imCanvasStripN[i * cnv_width + (j + sW/2)] = pGuide[i * width + j];
            imCanvasStripN[(cnv_height - i - 1) * cnv_width + (j + sW/2)] = pGuide[(height - i - 1) * width + j];
            imCanvasStripG[i * cnv_width + (j + sW/2)] = pGuide[i * width + j];
            imCanvasStripG[(cnv_height - i - 1) * cnv_width + (j + sW/2)] = pGuide[(height - i - 1) * width + j];
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
            imCanvasStripN[(i + sW/2) * cnv_width + j] = pGuide[i * width + j];
            imCanvasStripN[(i + sW/2) * cnv_width + (cnv_width - j - 1)] = pGuide[i * width + (width - j - 1)];
            imCanvasStripG[(i + sW/2) * cnv_width + j] = pGuide[i * width + j];
            imCanvasStripG[(i + sW/2) * cnv_width + (cnv_width - j - 1)] = pGuide[i * width + (width - j - 1)];
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

            out_img = (short)((double)pGuide[i * width + j] * sum_a + sum_b);
            pSmooth[i * width + j] = out_img;
            pTexture[i * width + j] = pGuide[i * width + j] - out_img;
        }
    }
}


//Guided image filter, guided img = input img (for DDE filter)
void HawkProcessing::runGIFfilter()
{
    int i, j, m, n;
    unsigned int sW = AgcP.sizeW;
    unsigned int width = ImgSz.width;
    unsigned int height = ImgSz.height;
    double eps = (AgcP.algo_step == 1) ? AgcP.eps1 : AgcP.eps2;
    //pointer to static arrays
    short *pBase = (AgcP.algo_step == 1) ? &imBase1[0] : &imBase2[0];
    float *paGIF = (AgcP.algo_step == 1) ? &a1GIF[0] : &a2GIF[0];
    //size of canvas image
    unsigned int cnv_width = width + (sW >> 1) * 2;
    unsigned int cnv_height = height + (sW >> 1) * 2;
    double mu, sigma;
    double sum_a, sum_b;

#ifdef _OPENMP
    omp_set_num_threads(nThreads);
    #pragma omp parallel for private(j)
#endif
    for (i = 0; i < height; i++)
    {
        for (j = 0; j < width; j++)
        {
            imCanvasDDE[(i + sW/2) * cnv_width + (j + sW/2)] = imNoisy[i * width + j];
        }
    }
    //fill canvas rows
    for (i = 0; i < sW/2; i++)
    {
        for (j = 0; j < width; j++)
        {
            imCanvasDDE[i * cnv_width + (j + sW/2)] = imNoisy[i * width + j];
            imCanvasDDE[(cnv_height - i - 1) * cnv_width + (j + sW/2)] = imNoisy[(height - i - 1) * width + j];

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
            imCanvasDDE[(i + sW/2) * cnv_width + j] = imNoisy[i * width + j];
            imCanvasDDE[(i + sW/2) * cnv_width + (cnv_width - j - 1)] = imNoisy[i * width + (width - j - 1)];

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

            pBase[i * width + j] = imCanvasDDE[(i + sW/2) * cnv_width + (j + sW/2)];
            paGIF[i * width + j] = aDDE[(i + sW/2) * cnv_width + (j + sW/2)];

        }
    }
}


void HawkProcessing::runHistProtection()
{
    int i;
    long int sum_hist = 0;
    //max value of each pixel (0x3fff)
    ushort n_valid = ImgSz.n_valid;
    unsigned int width = ImgSz.width;
    unsigned int height = ImgSz.height;
    ushort indexM = 0;
    //T = N_pix / n_valid = 18 for 640x512 image
    unsigned int histBord = AgcP.hist_bord;
    int hist_max;

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
        indexM = imBase2[i];
        hist[indexM]++;
    }

    //build cumulative sum of histogram
    for (i = 0; i < n_valid; i++)
    {
        sum_hist += (hist[i] > histBord) ? 1 : 0;
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
        imBaseP[i] = histSum[imBase2[i]];
    }
}


void HawkProcessing::runGainMaskEnhancement()
{
    int i;
    int width = ImgSz.width;
    int height = ImgSz.height;
    int max_detail = AgcP.max_detail;
    float delta, temp_ma, temp_fp;

    float max_ma = 0.0;
    float min_ma = 1.0;

    short max_im = -ImgSz.n_valid;
    short min_im = ImgSz.n_valid;
    float m1 = 0.0;
    float m2 = 0.0;
    float s1 = 0.0;
    float s2 = 0.0;

    //matrix Ma_ij = a1_ij * a2_ij
    //estimate Ma and means m1/m2
#ifdef _OPENMP
    omp_set_num_threads(nThreads);
    #pragma omp parallel for reduction(+:m1, m2)
#endif
    for (i = 0; i < width * height; i++)
    {
        MaGIF[i] = a1GIF[i] * a2GIF[i];
        m1 += a1GIF[i];
        m2 += a2GIF[i];
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
        s1 += (a1GIF[i] - m1) * (a1GIF[i] - m1);
        s2 += (a2GIF[i] - m2) * (a2GIF[i] - m2);
    }

    s1 = sqrt(s1 / (float)(width * height));
    s2 = sqrt(s2 / (float)(width * height));

    delta = m2 * ( 1 + (m2 + s2) / (m1 + s1));

    for (i=0; i < width * height; i++)
    {
        temp_ma = a1GIF[i] * a2GIF[i];
        MaGIF[i] =  (temp_ma < delta) ? temp_ma : delta;

        //max/min of Ma
        max_ma = (temp_ma > max_ma) ? temp_ma : max_ma;
        min_ma = (temp_ma < min_ma) ? temp_ma : min_ma;
        //max/min
        max_im = (imDetail[i] > max_im) ? imDetail[i] : max_im;
        min_im = (imDetail[i] < min_im) ? imDetail[i] : min_im;
    }

#ifdef _OPENMP
    omp_set_num_threads(nThreads);
    #pragma omp parallel for private(temp_ma, temp_fp) shared(max_ma, min_ma, max_im, min_im)
#endif
    for (i = 0; i < width * height; i++)
    {
        temp_ma = (MaGIF[i] - min_ma) / (max_ma - min_ma);
        temp_fp = (float)(imDetail[i] - min_im) / (float)(max_im - min_im) * (float)(max_detail) * temp_ma;
        imDetailP[i] = (short)temp_fp;
    }
}


//**********************************//
//Element-wise addition and subtraction
void HawkProcessing::addBaseImage()
{
    int i;
    int width = ImgSz.width;
    int height = ImgSz.height;

#ifdef _OPENMP
    omp_set_num_threads(nThreads);
    #pragma omp parallel for
#endif
    for (i = 0; i < width * height; i++)
    {
        imFinal[i] = imBaseP[i] + imDetailP[i];
    }

}


void HawkProcessing::subBaseImage()
{
    int i;
    int width = ImgSz.width;
    int height = ImgSz.height;

#ifdef _OPENMP
    omp_set_num_threads(nThreads);
    #pragma omp parallel for
#endif
    for (i = 0; i < width * height; i++)
    {
        imDetail[i] = imBase2[i] - imBase1[i];
    }
}


void HawkProcessing::subStripImage()
{
    int i;
    int width = ImgSz.width;
    int height = ImgSz.height;

#ifdef _OPENMP
    omp_set_num_threads(nThreads);
    #pragma omp parallel for
#endif
    for (i = 0; i < width * height; i++)
    {
        imFinal[i] = imNoisy[i] - imStrip[i];
    }
}


//************************************//
//Copy input image to internal massive
void HawkProcessing::copyInputImage(ushort *i_imNoisy)
{
    int i;
    int width = ImgSz.width;
    int height = ImgSz.height;

#ifdef _OPENMP
    omp_set_num_threads(nThreads);
    #pragma omp parallel for
#endif
    for (i = 0; i < width * height; i++)
    {
        imNoisy[i] = (short)(i_imNoisy[i]);
    }
}


void HawkProcessing::copyOutputImage(ushort *o_imFinal)
{
    int i;
    short temp;
    int width = ImgSz.width;
    int height = ImgSz.height;
    short max_k = ImgSz.n_valid;

#ifdef _OPENMP
    omp_set_num_threads(nThreads);
    #pragma omp parallel for private(temp) shared(max_k)
#endif
    for (i = 0; i < width * height; i++)
    {
        temp = imFinal[i];
        o_imFinal[i] = (ushort)((temp > max_k) ? max_k : (temp < 0) ? 0 : temp);
    }
}


//****************************//
//Other filters
void HawkProcessing::runFrameAveraging(ushort *io_img)
{
    int i = 0;
    float D_0 = 20.0;	//верхняя граница
    float D_1 = 50.0;  //нижняя граница
    float Q_1 = 0.5;     //коэф. сглаживания для верхней границы
    float Q_0 = 0.2;   //коэф. сглаживания для нижней границы
    float KCorr = 0.0;
    float dOut;
    unsigned int width = ImgSz.width;
    unsigned int height = ImgSz.height;

#ifdef _OPENMP
    omp_set_num_threads(nThreads);
    #pragma omp parallel for private(KCorr)
#endif
    for (i = 1; i < width * height; i++)
    {
        if (abs(io_img[i] - imOld[i]) >= D_1)
            KCorr = Q_1;
        else
        if (abs(io_img[i] - imOld[i]) <= D_0)
            KCorr = Q_0;
        else
            KCorr = (((float)(abs(io_img[i] - imOld[i])) - D_0) / (D_1 - D_0)) * (Q_1 - Q_0) + Q_0;

        dOut = (float)imOld[i] * KCorr + (float)io_img[i] * (1 - KCorr);

        //dOutBuffer[i] = (double)oldImg[i] * 0.2 + (double)img[i] * (1.0 - 0.2);

        io_img[i] = (ushort)dOut;

        imOld[i] = io_img[i];
    }
}


void HawkProcessing::runBlowOut(ushort *img)
{
    int i = 0, j = 0;
    int y = 0;
    ushort delta = 0;
    ushort sum1 = 0, sum1_1 = 0, sum1_2 = 0;
    ushort sum2 = 0, sum2_1 = 0, sum2_2 = 0;
    ushort sum3 = 0, sum3_1 = 0, sum3_2 = 0;
    ushort border = 1000; //2000
    ushort borderToH = 2000; //2000

    unsigned int width = ImgSz.width;
    unsigned int height = ImgSz.height;

    for (j = 1; j < (height - 1); j++)
    {
        //j = 136; //59;
        y = j * width;
        for (i = 3; i < width - 4; i++) //8
        {
            delta = abs(img[y + i] - img[y + i + 1]);

            if (delta >= border)
            {
                //white - blow out to down
                if (img[y + i] > img[y + i + 1])
                {
                    delta = abs(img[y + i + 1] - img[y + i + 2]); //разность для распознования выброса по одиночному пикселю...и соответственно его не обрабатываем
                    if (delta < borderToH)
                    {
                        //сумма в текущей строке   +++*----++++
                        sum1 = (img[y + i - 3] + img[y + i - 2] + img[y + i - 1] + img[y + i]) / 4;
                        sum2 = (img[y + i + 1] + img[y + i + 2] + img[y + i + 3] + img[y + i + 4]) / 4;
                        sum3 = (img[y + i + 5] + img[y + i + 6] + img[y + i + 7] + img[y + i + 8]) / 4;

                        sum1_1 = (img[y - width + i - 3] + img[y - width + i - 2] + img[y - width + i - 1] + img[y - width + i]) / 4;
                        sum2_1 = (img[y - width + i + 1] + img[y - width + i + 2] + img[y - width + i + 3] + img[y - width + i + 4]) / 4;
                        sum3_1 = (img[y - width + i + 5] + img[y - width + i + 6] + img[y - width + i + 7] + img[y - width + i + 8]) / 4;

                        sum1_2 = (img[y + width + i - 3] + img[y + width + i - 2] + img[y + width + i - 1] + img[y + width + i]) / 4;
                        sum2_2 = (img[y + width + i + 1] + img[y + width + i + 2] + img[y + width + i + 3] + img[y + width + i + 4]) / 4;
                        sum3_2 = (img[y + width + i + 5] + img[y + width + i + 6] + img[y + width + i + 7] + img[y + width + i + 8]) / 4;

                        if ((sum2 < sum1) && (sum2 < sum3) && (sum2 < sum1_1) && (sum2 < sum2_1) && (sum2 < sum3_1) && (sum2 < sum1_2) && (sum2 < sum2_2) && (sum2 < sum3_2))
                        {
                            img[y + i + 4] = (img[y - width + i + 3] + img[y - width + i + 4] + img[y - width + i + 5] + img[y + width + i + 3] + img[y + width + i + 4] + img[y + width + i + 5]) / 6;
                            img[y + i + 3] = (img[y - width + i + 2] + img[y - width + i + 3] + img[y - width + i + 4] + img[y + width + i + 2] + img[y + width + i + 3] + img[y + width + i + 4]) / 6;
                            img[y + i + 2] = (img[y - width + i + 1] + img[y - width + i + 2] + img[y - width + i + 3] + img[y + width + i + 1] + img[y + width + i + 2] + img[y + width + i + 3]) / 6;
                            img[y + i + 1] = (img[y - width + i]     + img[y - width + i + 1] + img[y - width + i + 2] + img[y + width + i]     + img[y + width + i + 1] + img[y + width + i + 2]) / 6;
                        }
                        else
                        {
                            if (i >= 8)
                            {
                                delta = abs(img[y + i + 1] - img[y + i + 2]);
                                if (delta < borderToH)
                                {
                                    //сумма в текущей строке    ++++---*++++
                                    sum1 = (img[y + i - 7] + img[y + i - 6] + img[y + i - 5] + img[y + i - 4]) / 4;
                                    sum2 = (img[y + i - 3] + img[y + i - 2] + img[y + i - 1] + img[y + i]) / 4;
                                    sum3 = (img[y + i + 1] + img[y + i + 2] + img[y + i + 3] + img[y + i + 4]) / 4;

                                    sum1_1 = (img[y - width + i - 7] + img[y - width + i - 6] + img[y - width + i - 5] + img[y - width + i - 4]) / 4;
                                    sum2_1 = (img[y - width + i - 3] + img[y - width + i - 2] + img[y - width + i - 1] + img[y - width + i]) / 4;
                                    sum3_1 = (img[y - width + i + 1] + img[y - width + i + 2] + img[y - width + i + 3] + img[y - width + i + 4]) / 4;

                                    sum1_2 = (img[y + width + i - 7] + img[y + width + i - 6] + img[y + width + i - 5] + img[y + width + i - 4]) / 4;
                                    sum2_2 = (img[y + width + i - 3] + img[y + width + i - 2] + img[y + width + i - 1] + img[y + width + i]) / 4;
                                    sum3_2 = (img[y + width + i + 1] + img[y + width + i + 2] + img[y + width + i + 3] + img[y + width + i + 4]) / 4;

                                    if ((sum2 > sum1) && (sum2 > sum3) && (sum2 > sum1_1) && (sum2 > sum2_1) && (sum2 > sum3_1) && (sum2 > sum1_2) && (sum2 > sum2_2) && (sum2 > sum3_2))
                                    {
                                        img[y + i - 3] = (img[y - width + i - 4] + img[y - width + i - 3] + img[y - width + i - 2] + img[y + width + i - 4] + img[y + width + i - 3] + img[y + width + i - 2]) / 6;
                                        img[y + i - 2] = (img[y - width + i - 3] + img[y - width + i - 2] + img[y - width + i - 1] + img[y + width + i - 3] + img[y + width + i - 2] + img[y + width + i - 1]) / 6;
                                        img[y + i - 1] = (img[y - width + i - 2] + img[y - width + i - 1] + img[y - width + i]     + img[y + width + i - 2] + img[y + width + i - 1] + img[y + width + i])     / 6;
                                        img[y + i]	   = (img[y - width + i - 1] + img[y - width + i]     + img[y - width + i + 1] + img[y + width + i - 1] + img[y + width + i]     + img[y + width + i + 1]) / 6;
                                    }
                                }
                            }
                        }
                    }
                }
                else
                //black - blow out to up
                if (img[y + i] < img[y + i + 1])
                {
                    delta = abs(img[y + i + 1] - img[y + i + 2]);
                    if (delta < (borderToH))
                    {
                        //сумма в текущей строке  ---*++++----
                        sum1 = (img[y + i - 3] + img[y + i - 2] + img[y + i - 1] + img[y + i]) / 4;
                        sum2 = (img[y + i + 1] + img[y + i + 2] + img[y + i + 3] + img[y + i + 4]) / 4;
                        sum3 = (img[y + i + 5] + img[y + i + 6] + img[y + i + 7] + img[y + i + 8]) / 4;

                        sum1_1 = (img[y - width + i - 3] + img[y - width + i - 2] + img[y - width + i - 1] + img[y - width + i]) / 4;
                        sum2_1 = (img[y - width + i + 1] + img[y - width + i + 2] + img[y - width + i + 3] + img[y - width + i + 4]) / 4;
                        sum3_1 = (img[y - width + i + 5] + img[y - width + i + 6] + img[y - width + i + 7] + img[y - width + i + 8]) / 4;

                        sum1_2 = (img[y + width + i - 3] + img[y + width + i - 2] + img[y + width + i - 1] + img[y + width + i]) / 4;
                        sum2_2 = (img[y + width + i + 1] + img[y + width + i + 2] + img[y + width + i + 3] + img[y + width + i + 4]) / 4;
                        sum3_2 = (img[y + width + i + 5] + img[y + width + i + 6] + img[y + width + i + 7] + img[y + width + i + 8]) / 4;

                        if ((sum2 > sum1) && (sum2 > sum3) && (sum2 > sum1_1) && (sum2 > sum2_1) && (sum2 > sum3_1) && (sum2 > sum1_2) && (sum2 > sum2_2) && (sum2 > sum3_2))
                        {
                            img[y + i + 4] = (img[y - width + i + 3] + img[y - width + i + 4] + img[y - width + i + 5] + img[y + width + i + 3] + img[y + width + i + 4] + img[y + width + i + 5]) / 6;
                            img[y + i + 3] = (img[y - width + i + 2] + img[y - width + i + 3] + img[y - width + i + 4] + img[y + width + i + 2] + img[y + width + i + 3] + img[y + width + i + 4]) / 6;
                            img[y + i + 2] = (img[y - width + i + 1] + img[y - width + i + 2] + img[y - width + i + 3] + img[y + width + i + 1] + img[y + width + i + 2] + img[y + width + i + 3]) / 6;
                            img[y + i + 1] = (img[y - width + i]     + img[y - width + i + 1] + img[y - width + i + 2] + img[y + width + i]     + img[y + width + i + 1] + img[y + width + i + 2]) / 6;
                        }
                        else
                        {
                            if (i >= 8)
                            {
                                delta = abs(img[y + i + 1] - img[y + i + 2]);
                                if (delta < (borderToH))
                                {
                                    //сумма в текущей строке   ++++---*++++
                                    sum1 = (img[y + i - 7] + img[y + i - 6] + img[y + i - 5] + img[y + i - 4]) / 4;
                                    sum2 = (img[y + i - 3] + img[y + i - 2] + img[y + i - 1] + img[y + i]) / 4;
                                    sum3 = (img[y + i + 1] + img[y + i + 2] + img[y + i + 3] + img[y + i + 4]) / 4;

                                    sum1_1 = (img[y - width + i - 7] + img[y - width + i - 6] + img[y - width + i - 5] + img[y - width + i - 4]) / 4;
                                    sum2_1 = (img[y - width + i - 3] + img[y - width + i - 2] + img[y - width + i - 1] + img[y - width + i]) / 4;
                                    sum3_1 = (img[y - width + i + 1] + img[y - width + i + 2] + img[y - width + i + 3] + img[y - width + i + 4]) / 4;

                                    sum1_2 = (img[y + width + i - 7] + img[y + width + i - 6] + img[y + width + i - 5] + img[y + width + i - 4]) / 4;
                                    sum2_2 = (img[y + width + i - 3] + img[y + width + i - 2] + img[y + width + i - 1] + img[y + width + i]) / 4;
                                    sum3_2 = (img[y + width + i + 1] + img[y + width + i + 2] + img[y + width + i + 3] + img[y + width + i + 4]) / 4;

                                    if ((sum2 < sum1) && (sum2 < sum3) && (sum2 < sum1_1) && (sum2 < sum2_1) && (sum2 < sum3_1) && (sum2 < sum1_2) && (sum2 < sum2_2) && (sum2 < sum3_2))
                                    {
                                        img[y + i - 3] = (img[y - width + i - 4] + img[y - width + i - 3] + img[y - width + i - 2] + img[y + width + i - 4] + img[y + width + i - 3] + img[y + width + i - 2]) / 6;
                                        img[y + i - 2] = (img[y - width + i - 3] + img[y - width + i - 2] + img[y - width + i - 1] + img[y + width + i - 3] + img[y + width + i - 2] + img[y + width + i - 1]) / 6;
                                        img[y + i - 1] = (img[y - width + i - 2] + img[y - width + i - 1] + img[y - width + i]     + img[y + width + i - 2] + img[y + width + i - 1] + img[y + width + i])     / 6;
                                        img[y + i]	   = (img[y - width + i - 1] + img[y - width + i]     + img[y - width + i + 1] + img[y + width + i - 1] + img[y + width + i]     + img[y + width + i + 1]) / 6;
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}


void HawkProcessing::runZoom2x(ushort *io_img)
{
    int i = 0, i1 = 0, j = 0, j1 = 0, y = 0;

    j1 = 127;
    i1 = 159;

    unsigned int width = ImgSz.width;
    unsigned int height = ImgSz.height;

#ifdef _OPENMP
    omp_set_num_threads(nThreads);
    #pragma omp parallel for private(i)
#endif
    for (j = 0; j < height/2; j++)
    {
        for (i = 0; i < width/2; i++)
        {
            bufrez[i + j * width/2] = io_img[i + i1 + (j + j1) * width];
        }
    }

#ifdef _OPENMP
    omp_set_num_threads(nThreads);
    #pragma omp parallel for
#endif
    for (j = 0; j < width*height; j++)
        io_img[j] = 0;

#ifdef _OPENMP
    omp_set_num_threads(nThreads);
    #pragma omp parallel for private(i)
#endif
    for (j = 0; j < height; j = j + 2)
        for (i = 0; i < width; i = i + 2)
        {
            io_img[i + j * width] = bufrez[(i + j * width)/4];
        }

#ifdef _OPENMP
    omp_set_num_threads(nThreads);
    #pragma omp parallel for private(i)
#endif
    //line interpolate
    for (j = 0; j < height; j = j + 2)
        for (i = 1; i < width - 1; i = i + 2)
            io_img[i + j * width] = (io_img[i - 1 + j * width] + io_img[i + 1 + j * width]) / 2;

#ifdef _OPENMP
    omp_set_num_threads(nThreads);
    #pragma omp parallel for private(j)
#endif
    //row interpolate
    for (i = 0; i < width; i = i + 2)
        for (j = 1; j < height - 1; j = j + 2)
            io_img[i + j * width] = (io_img[i + (j - 1) * width] + io_img[i + (j + 1) * width]) / 2;

#ifdef _OPENMP
    omp_set_num_threads(nThreads);
    #pragma omp parallel for private(i)
#endif
    //biline interpolate
    for (j = 1; j < height - 1; j = j + 2)
        for (i = 1; i < width - 1; i = i + 2)
            io_img[i + j * width] = (io_img[i - 1 + (j - 1) * width] + io_img[i + 1 + (j - 1) * width] + io_img[i - 1 + (j + 1) * width] + io_img[i + 1 + (j + 1) * width]) / 4;
}


void HawkProcessing::runPosNeg(ushort *io_img)
{
    int i = 0;
    unsigned int imgMax = ImgSz.n_valid;
    unsigned int width = ImgSz.width;
    unsigned int height = ImgSz.height;

#ifdef _OPENMP
    omp_set_num_threads(nThreads);
    #pragma omp parallel for
#endif
    for (i = 0; i < width * height; i++)
        io_img[i] = imgMax - io_img[i];
}


//***************************//
//2PT calibration
bool HawkProcessing::frameSumming(ushort *io_img)
{
    ushort nFrame1PT = 32;	  //количество кадров для калибровки
    //uInt16 AVG = 0x1fff;    //средний уровень
    unsigned int width = ImgSz.width;
    unsigned int height = ImgSz.height;
    int i = 0;

    if (cntPTFrame < nFrame1PT)
    {
#ifdef _OPENMP
            omp_set_num_threads(nThreads);
            #pragma omp parallel for
#endif
            for (i = 0; i < width * height; i++)
            {
                SumKoefBuff[i] = SumKoefBuff[i] + io_img[i];
            }
    }
    else
    if (cntPTFrame == nFrame1PT)
    {
#ifdef _OPENMP
            omp_set_num_threads(nThreads);
            #pragma omp parallel for
#endif
            for ( i = 0; i < width * height; i++)
            {
                KoefBuff[i] = (ushort)((double)SumKoefBuff[i] / (double)nFrame1PT);
            }
    }
    else
    if (cntPTFrame == (nFrame1PT + 1))
    {
#ifdef _OPENMP
            omp_set_num_threads(nThreads);
            #pragma omp parallel for
#endif
        for (i = 0; i < (width * height); i++)
            SumKoefBuff[i] = 0;

        //StatusMsgShow(PTKOEF_DONE);

        return true;
    }

    return false;
}


bool HawkProcessing::prepCor2PT(ushort *io_img)
{
    ushort nFrame1PT = 32; //количество кадров для калибровки
    //uInt16 AVG = 0x1fff;    //средний уровень
    ushort iBufPix = 0;
    unsigned int width = ImgSz.width;
    unsigned int height = ImgSz.height;
    double avgSum = 0;
    int i = 0;

#ifdef _OPENMP
            omp_set_num_threads(nThreads);
            #pragma omp parallel for reduction(+:avgSum)
#endif
    for (i = 0; i < width * height; i++)
        avgSum += (double)io_img[i];

    avgSum /= (double)(width * height);

#ifdef _OPENMP
            omp_set_num_threads(nThreads);
            #pragma omp parallel for
#endif
    for ( i = 0; i < width * height; i++)
        addImg[i] = avgSum - ((double)Kc[i] *(double)io_img[i])  / 1024.0;

    return true;
}


void HawkProcessing::calibImg2PT(ushort *io_img)
{
    int i = 0;
    ushort temp;
    float iPixMult = 0;
    unsigned int width = ImgSz.width;
    unsigned int height = ImgSz.height;
    unsigned int imgMax = ImgSz.n_valid;

#ifdef _OPENMP
            omp_set_num_threads(nThreads);
            #pragma omp parallel for private(temp, iPixMult)
#endif
    for (i = 0; i < width * height; i++)
    {
        iPixMult = ((double)io_img[i] * (double)Kc[i]) / 1024.0;
        temp = (ushort)(iPixMult + addImg[i]); //add
        io_img[i] = (temp < 0) ? 0 : ((temp > imgMax) ? imgMax : temp);
    }
}


//*****************************//
//4PT Calibration
void HawkProcessing::initTable4PT()
{
    FILE *input = NULL;
    double number = 0;
    int i = 0;
    unsigned int width = ImgSz.width;
    unsigned int height = ImgSz.height;

    input = fopen("C:/xCpp_pr/CALIBRI/ColibriTerminal/calk_hawk_2.k", "rb");

    fread(&number, sizeof(double), 1, input);
    a_e = (float)number;
    fread(&number, sizeof(double), 1, input);
    b_e = (float)number;
    fread(&number, sizeof(double), 1, input);
    c_e = (float)number;
    fread(&number, sizeof(double), 1, input);
    d_e = (float)number;
    fread(&number, sizeof(double), 1, input);
    e_e = (float)number;

    for (i = 0; i < width * height; i++)
    {
        fread(&number, sizeof(double), 1, input);
        a_i[i] = (float)number;
        fread(&number, sizeof(double), 1, input);
        b_i[i] = (float)number;
        fread(&number, sizeof(double), 1, input);
        c_i[i] = (float)number;
        fread(&number, sizeof(double), 1, input);
        d_i[i] = (float)number;
        fread(&number, sizeof(double), 1, input);
        e_i[i] = (float)number;
    }

    fclose(input);
}


void HawkProcessing::prepCor4PT(ushort *io_img)
{
    int i = 0;
    float Tbi = 0;
    float Ts = StripP.Ts;
    float buf = 0;
    double avgSum = 0;
    unsigned int width = ImgSz.width;
    unsigned int height = ImgSz.height;
    unsigned int imgMax = ImgSz.n_valid;

#ifdef _OPENMP
            omp_set_num_threads(nThreads);
            #pragma omp parallel for
#endif
    for (i = 0; i < width * height; i++)
        addImg[i] = 0;

#ifdef _OPENMP
            omp_set_num_threads(nThreads);
            #pragma omp parallel for reduction(+:avgSum)
#endif
    for (i = 0; i < width * height; i++)
        avgSum += (double)io_img[i];

    avgSum /= (double)(width * height);

#ifdef _OPENMP
            omp_set_num_threads(nThreads);
            #pragma omp parallel for private(Tbi, buf)
#endif
    for (i = 0; i < width * height; i++)
    {
        if (a_i[i] != 0)
        {
            Tbi = (log(((float)io_img[i] - (a_i[i] + e_i[i] * Ts)) / (b_i[i] - (float)io_img[i] + (a_i[i] + e_i[i] * Ts))) + c_i[i]) / d_i[i];
            buf = (a_e + (b_e / (1 + exp(c_e - d_e * Tbi))) + e_e * Ts);
            io_img[i] = (buf < 0) ? 0 : (((ushort)buf > imgMax) ? imgMax : (ushort)buf);
            addImg[i] = avgSum - buf;
        }
    }
}


void HawkProcessing::calibImg4PT(ushort *io_img)
{
    int i = 0;
    float Tbi = 0;
    float Ts = StripP.Ts;
    ushort buf = 0;

    unsigned int width = ImgSz.width;
    unsigned int height = ImgSz.height;
    unsigned int imgMax = ImgSz.n_valid;

#ifdef _OPENMP
    omp_set_num_threads(omp_get_max_threads());
    #pragma omp parallel for private(Tbi, buf)
#endif
    for (i = 0; i < width * height; i++)
    {
        if (a_i[i] != 0)
        {
            Tbi = (log(((float)io_img[i] - (a_i[i] + e_i[i] * Ts)) / (b_i[i] - (float)io_img[i] + (a_i[i] + e_i[i] * Ts))) + c_i[i]) / d_i[i];
            buf = (ushort)((a_e + (b_e / (1 + exp(c_e - d_e * Tbi))) + e_e * Ts) + addImg[i]);
            io_img[i] = (buf < 0) ? 0 : ((buf > imgMax) ? imgMax : buf);
        }
    }
}


//***********************//
//update params slots
void HawkProcessing::updateProcParams(int id, bool state)
{
    switch (id)
    {
        case 0: ProcP.dde = state;
            break;
        case 1: ProcP.strip = state;
            break;
        case 2: ProcP.pt2_calib = state;
            break;
        case 3: ProcP.pt2_pt1 = state;
            break;
        case 4: ProcP.pt4_calib = state;
            break;
        case 5: ProcP.pt4_pt2 = state;
            break;
        case 6: ProcP.blow_out = state;
            break;
        case 7: ProcP.frame_avg = state;
            break;
        case 8: ProcP.pos_neg = state;
            break;
        case 9: ProcP.zoom_2x = state;
            break;
        default: {}
    }
}

void HawkProcessing::updateAgcParams(int id, QString message)
{
    switch (id)
    {
        bool ok;
        case 0:
        {
            int sW = message.toInt();
            switch (sW)
            {
                case 3:
                    AgcP.sizeW = 3;
                    break;
                case 5:
                    AgcP.sizeW = 5;
                    break;
                case 7:
                    AgcP.sizeW = 7;
                    break;
                default:
                    AgcP.sizeW = 3;
                    //emit sendAgcParams(id, QString::number(AgcP.sizeW));
                    break;
            }
        }
        case 1:
        {
            float eps = message.toFloat(&ok);
            if (ok)
                AgcP.eps1 = eps;
            else
            {
                AgcP.eps1 = 2500.0;
                //emit sendAgcParams(id, QString::number((double)AgcP.eps1, 'f', 1));
            }
        }
        case 2:
        {
            float eps = message.toFloat(&ok);
            if (ok)
                AgcP.eps2 = eps;
            else
            {
                AgcP.eps2 = 250.0;
                //emit sendAgcParams(id, QString::number((double)AgcP.eps2, 'f', 1));
            }
        }
        case 3:
        {
            int max_detail = message.toInt(&ok);
            if (ok)
                AgcP.max_detail = max_detail;
            else
            {
                AgcP.max_detail = 512;
                //emit sendAgcParams(id, QString::number(AgcP.max_detail));
            }
        }
        case 4:
        {
            int histBord = message.toInt(&ok);
            if (ok)
                AgcP.hist_bord = histBord;
            else
            {
                AgcP.hist_bord = 20;
               // emit sendAgcParams(id, QString::number(AgcP.hist_bord));
            }
        }
        default: {}
    }
}


void HawkProcessing::updateStripParams(int id, QString message)
{
    switch (id)
    {
        bool ok;
        case 0:
        {
            int sW = message.toInt(&ok);
            switch (sW)
            {
                case 5:
                    StripP.sizeW = 5;
                    break;
                case 7:
                    StripP.sizeW = 7;
                    break;
                case 9:
                    StripP.sizeW = 9;
                    break;
                default:
                    StripP.sizeW = 7;
                    //emit sendStripParams(id, QString::number(StripP.sizeW));
                    break;
            }
        }
        case 1:
        {
            float eps = message.toFloat(&ok);
            if (ok)
            {
                StripP.eps = eps;
                //emit sendStripParams(id, QString::number((double)StripP.eps, 'f', 1));
            }
            else
            {
                StripP.eps = 250.0;
                //emit sendStripParams(id, QString::number((double)StripP.eps, 'f', 1));
            }
        }
        case 2:
        {
            float Ts = message.toFloat(&ok);
            if (ok)
                StripP.Ts = Ts;
            else
                StripP.Ts = 20.0;
        }
        default: {}
    }
}

//FFT functions
void HawkProcessing::hawkRunFFT(int id, int n_line) {
    //0 - line fft, 1 - frame fft
    switch (id)
    {
        case 0:
            fftP.lineFFT = true;
            fftP.numLine = n_line;
            break;
        case 1:
            fftP.frameFFT = true;
            break;
        default:
            fftP.lineFFT  = false;
            fftP.frameFFT = false;
            break;
    }
}


void HawkProcessing::runLineFFT(ushort *io_img) {
    uint i;
    data_processor_t dfft;
    ushort *pm = io_img + ImgSz.width * fftP.numLine;

    dfft = data_proc_init(ImgSz.width, 0);
    //data_out = data_proc_init(ImgSz.width, 1);
    data_proc_copy_image(dfft, pm, 0, ImgSz.width);

    kiss_fftr(dfft->kiss_fft_state, dfft->time, dfft->freq);


    QVector<double> abs((int)(ImgSz.width));
    for (i = 0; i < ImgSz.width; i++)
    {
        abs[i] = sqrt(dfft->freq[i].r * dfft->freq[i].r + dfft->freq[i].i * dfft->freq[i].i);
    }

    data_proc_close(dfft);

    emit onPlotLineFFT(abs, ImgSz.width);
}


void HawkProcessing::runFrameFFT(ushort *io_img) {
    uint i;
    data_processor_t dfft;
    ushort *pm = io_img;
    uint wh = ImgSz.width * ImgSz.height;

    dfft = data_proc_init(wh, 0);
    //data_out = data_proc_init(ImgSz.width, 1);
    data_proc_copy_image(dfft, pm, 0, wh);

    kiss_fftr(dfft->kiss_fft_state, dfft->time, dfft->freq);


    QVector<double> abs((int)wh);
    for (i = 0; i < wh; i++)
    {
        abs[i] = sqrt(dfft->freq[i].r * dfft->freq[i].r + dfft->freq[i].i * dfft->freq[i].i);
    }

    data_proc_close(dfft);

    emit onPlotFrameFFT(abs, ImgSz.width, ImgSz.height);
}
