#ifndef BLUR_H
#define BLUR_H

#include <QImage>
#include <QDebug>
#include <vector>
#include <algorithm>
#include <math.h>
#ifdef _OPENMP
#include <omp.h>
#endif

#ifndef M_PI
#define M_PI 3.14159265358979323846
#endif

#define nullptr NULL
#define CLAMP(v, min, max) if (v < min) { v = min; } else if (v > max) { v = max; }

template <typename dataT, typename maskT>
class BlurHD
{
    typedef struct blurParams_ {
        double gammaCorr;
        double delta;
        double borderBright;
        int badThres;
    } blurParams;

public:
    BlurHD(int width, int height, int levels);
    ~BlurHD();
    void runBlur();
    void setInputImg(dataT *imRaw);
    QImage getFinalImg();
    dataT* getFinalArray();
    void updateParams(int badThres, double borderBright, double gammaCorr, double delta);

private:
    void copyImg(dataT *src, dataT *dst, unsigned int level);
    void convolutionImg();
    void nearestInterpolation();
    void bicubicInterpolation();
    void getDiff(int level);
    void sumFinalImg();
    void maskFilter3x3(maskT *mask, int maskSize);

    void gaussFilter(int maskSize, float sigma);
    double gauss(double sigma, double x);
    //demofox resize
    float CubicHermite (float A, float B, float C, float D, float t);
    float Lerp (float A, float B, float t);
    dataT GetPixelClamped (int x, int y);
    dataT SampleNearest (float u, float v);
    dataT SampleLinear (float u, float v);
    dataT SampleBicubic (float u, float v);
    void ResizeImage (bool scale, int degree);

    blurParams blurP;

    unsigned int numLevels;
    unsigned int currentLevel;
    unsigned int imWidth[4];
    unsigned int imHeight[4];
    unsigned int imSize[4];

    dataT *imInput;
    dataT *imTemp;
    dataT *imBuffer;
    dataT *imFinal;
    dataT **imLevels;
    float **imDiffs;

    float imDouble[640];

//public slots:
    //void updateParams(int delta, int badThres, double gamma, double d);
};

template <typename dataT, typename maskT>
BlurHD<dataT, maskT>::BlurHD(int width, int height, int levels)
{
    blurP.gammaCorr = 0.7;
    blurP.delta = 70.0;
    blurP.borderBright = 3.0;
    blurP.badThres = 10;

#ifdef _OPENMP
    int nThreads = omp_get_max_threads( );
    qDebug() << "Max threads: " << nThreads;
    omp_set_num_threads(nThreads);
#endif

    numLevels = levels;
    imWidth[0] = width;
    imHeight[0] = height;
    imSize[0] = width * height;

    //qDebug() << "levels: " << numLevels;

    for (int i = 1; i < numLevels + 1; i++) {
        imWidth[i] = int((float)imWidth[i-1] / 3.0);
        imHeight[i] = int((float)imHeight[i-1] / 3.0);
        imSize[i] = imWidth[i] * imHeight[i];
        //qDebug() << i << " width: " << imWidth[i] << "height: " << imHeight[i];
    }

    try {
        imInput       = new dataT[imSize[0]];
        imTemp        = new dataT[imSize[0]];
        imBuffer      = new dataT[imSize[0]];
        imFinal       = new dataT[imSize[0]];
        imLevels      = new dataT*[numLevels + 1];
        imDiffs       = new float*[numLevels + 1];
    }
    catch (...) {
        delete[] imInput    ; imFinal   = nullptr;
        delete[] imTemp     ; imTemp    = nullptr;
        delete[] imBuffer   ; imBuffer  = nullptr;
        delete[] imFinal    ; imFinal   = nullptr;
        delete[] imLevels   ; imLevels  = nullptr;
        delete[] imDiffs    ; imDiffs   = nullptr;
    }

    for (int i = 0; i < numLevels + 1; i++) {
        try {
            imLevels[i] = new dataT[imSize[i]];
            imDiffs[i]  = new float[imSize[0]];
        }
        catch (...) {
            delete[] imLevels[i] ; imLevels[i]  = nullptr;
            delete[] imDiffs[i]  ; imDiffs[i]   = nullptr;
        }
    }

    currentLevel = 0;
}


template <typename dataT, typename maskT>
BlurHD<dataT, maskT>::~BlurHD()
{
    delete[] imInput    ; imFinal   = nullptr;
    delete[] imTemp     ; imTemp    = nullptr;
    delete[] imBuffer   ; imBuffer  = nullptr;
    delete[] imFinal    ; imFinal   = nullptr;

    for (int i = 0; i < numLevels + 1; i++) {
        delete[] imLevels[i];  imLevels[i]  = nullptr;
        delete[] imDiffs[i] ;  imDiffs[i]   = nullptr;
     }
    delete[] imLevels   ; imLevels  = nullptr;
    delete[] imDiffs    ; imDiffs   = nullptr;
}


template <typename dataT, typename maskT>
void BlurHD<dataT, maskT>::runBlur()
{
    maskT mask3x3[9] = {1, 2, 1,
                        2, 4, 2,
                        1, 2, 1};
    //QTime time = QTime::currentTime();

#ifdef _OPENMP
    int nThreads = omp_get_max_threads( );
    omp_set_num_threads(nThreads);
    //qDebug() << "threads: " << omp_get_num_threads();
#endif

    copyImg(imInput, imLevels[0], 0);
    maskFilter3x3(&mask3x3[0], 3);
    copyImg(imLevels[0], imBuffer, 0);

    for (int level = 0; level < numLevels; level++) {
        //convolutionImg();
        ResizeImage(false, 0);
        maskFilter3x3(&mask3x3[0], 3);
        //up 1/2/3 levels
        for (int i = 0; i < level + 1; i++) {
            //nearestInterpolation();
            //bicubicInterpolation();
            //scale: true -1 lvl, false + 1 lvl; degree: 0 - nearest, 1 - linear, 2 - bicubic
            ResizeImage(true, 1);
            maskFilter3x3(&mask3x3[0], 3);
        }
        //get border img dD = d_i - d_i+1
        getDiff(level);
        //set current level img
        currentLevel = level + 1;
        //copy evolve img to Input buffer
        copyImg(imLevels[0], imBuffer, 0);
    }

    //copyImg(imDiffs[0], imFinal, 0);
    sumFinalImg();
    copyImg(imFinal, imLevels[0], 0);
    maskFilter3x3(&mask3x3[0], 3);
    copyImg(imLevels[0], imFinal,0);

}


template <typename dataT, typename maskT>
void BlurHD<dataT, maskT>::setInputImg(dataT *imRaw)
{
    for (int i = 0; i < imSize[0]; i++) {
        imInput[i] = imRaw[i];
    }

    currentLevel = 0;
}


template <typename dataT, typename maskT>
QImage BlurHD<dataT, maskT>::getFinalImg()
{
    QImage imPix(imWidth[0], imHeight[0], QImage::Format_RGB32);

    for(int i = 0; i < imWidth[0]; i++)
    {
        for(int j = 0; j < imHeight[0]; j++)
        {
            QRgb rgb = qRgb((int)imFinal[i + j*imWidth[0]], (int)imFinal[i + j*imWidth[0]], (int)imFinal[i + j*imWidth[0]]);
            imPix.setPixel(i, j, rgb);
        }
    }
    return imPix;
}


template <typename dataT, typename maskT>
dataT* BlurHD<dataT, maskT>::getFinalArray()
{
    return imFinal;
}

template <typename dataT, typename maskT>
void BlurHD<dataT, maskT>::copyImg(dataT *src, dataT *dst, unsigned int level)
{
#ifdef _OPENMP
    #pragma omp parallel for
#endif
    for (int i = 0; i < imSize[level]; i++) {
        dst[i] = src[i];
    }
}


template <typename dataT, typename maskT>
void BlurHD<dataT, maskT>::convolutionImg()
{
    int sL = currentLevel;
    int eL = ++currentLevel;
    for(int j = 0; j < imHeight[eL]; j++)
    {
        for (int i = 0; i < imWidth[eL]; i++)
        {
            imLevels[eL][i + j*imWidth[eL]] = imLevels[sL][(i*3+1) + (j*3+1)*imWidth[sL]];
        }
    }
    currentLevel = eL;
}


template <typename dataT, typename maskT>
void BlurHD<dataT, maskT>::nearestInterpolation()
{
    int sL = currentLevel;
    int eL = --currentLevel;

    for(int j = 1; j < imHeight[sL]; j++)
    {
        for (int i = 1; i < imWidth[sL]; i++)
        {
            for(int n = -1; n < 2; n++)
                for (int m = -1; m < 2; m++)
                    imLevels[eL][(3*i+n) + (3*j+m)*imWidth[eL]] = imLevels[sL][i + j*imWidth[sL]];
        }
    }
}


template <typename dataT, typename maskT>
void BlurHD<dataT, maskT>::bicubicInterpolation()
{
    int sL = currentLevel;
    int eL = --currentLevel;

    const float tx = float(imWidth[sL]) / imWidth[eL];
    const float ty = float(imHeight[sL]) / imHeight[eL];

    float C[5] = { 0 };

#ifdef _OPENMP
    #pragma omp parallel for shared(sL, eL) private(C)
#endif
    for (int i = 0; i < imHeight[eL]; ++i)
    {
        for (int j = 0; j < imWidth[eL]; ++j)
        {
            const int x = int(tx * j);
            const int y = int(ty * i);
            const float dx = tx * j - x;
            const float dy = ty * i - y;

            for (int jj = 0; jj < 4; ++jj)
            {
                const int z = y - 1 + jj;
                float a0 = imLevels[sL][imWidth[sL] * z + x];
                float d0 = imLevels[sL][imWidth[sL] * z + (x - 1)] - a0;
                float d2 = imLevels[sL][imWidth[sL] * z + (x + 1)] - a0;
                float d3 = imLevels[sL][imWidth[sL] * z + (x + 2)] - a0;
                float a1 = -1.0 / 3 * d0 + d2 - 1.0 / 6 * d3;
                float a2 = 1.0 / 2 * d0 + 1.0 / 2 * d2;
                float a3 = -1.0 / 6 * d0 - 1.0 / 2 * d2 + 1.0 / 6 * d3;
                C[jj] = a0 + a1 * dx + a2 * dx * dx + a3 * dx * dx * dx;

                d0 = C[0] - C[1];
                d2 = C[2] - C[1];
                d3 = C[3] - C[1];
                a0 = C[1];
                a1 = -1.0 / 3 * d0 + d2 -1.0 / 6 * d3;
                a2 = 1.0 / 2 * d0 + 1.0 / 2 * d2;
                a3 = -1.0 / 6 * d0 - 1.0 / 2 * d2 + 1.0 / 6 * d3;
                float temp = (a0 + a1 * dy + a2 * dy * dy + a3 * dy * dy * dy);
                imLevels[eL][i * imWidth[eL] + j] = (temp < 0) ? 0 : (temp > 255) ? 255 : (dataT)temp;
            }
        }
    }
}

template <typename dataT, typename maskT>
void BlurHD<dataT, maskT>::getDiff(int level)
{
    int cL = level;
    dataT absT;
    int signT;
    double temp;

#ifdef _OPENMP
    #pragma omp parallel for private(absT, signT, temp)
#endif
    for (int i = 0; i < imSize[0]; i++) {
        absT = (imBuffer[i] > imLevels[0][i]) ? imBuffer[i] - imLevels[0][i] : imLevels[0][i] - imBuffer[i];
        temp = (double)absT;
        signT = (imBuffer[i] > imLevels[0][i]) ? 1 : -1;
        imDiffs[cL][i] = (float)signT * pow((1-exp(-blurP.delta*temp*temp))*temp, blurP.gammaCorr);

    }
}


template<typename dataT, typename maskT>
void BlurHD<dataT, maskT>::sumFinalImg()
{
    int temp, min, max, typeMult;
    float sum, fp;
    std::vector<int> sumVec(imSize[0]);
    int div[numLevels];
    std::fill_n(div, numLevels, 2);
    div[0] = 3;

#ifdef _OPENMP
    #pragma omp parallel for private(sum)
#endif
    for (int i = 0; i < imSize[0]; i++) {
        sum = (float)imInput[i];
        //temp = (int)imLevels[0][i];
        for (int k = 0; k < numLevels - 1; k++) {
            sum += blurP.borderBright * imDiffs[k][i] * 3 / div[k];
        }
        sumVec[i] = (int)sum;
    }

    std::vector<int> sortVec(sumVec);
    std::sort(sortVec.begin(), sortVec.end());

    min = sortVec[blurP.badThres];
    max = sortVec[imSize[0] - blurP.badThres];
    typeMult = (1 << (sizeof(dataT) * 8)) - 1;

#ifdef _OPENMP
    #pragma omp parallel for shared(min, max, typeMult) private(fp, temp)
#endif
    for (int i = 0; i < imSize[0]; i++) {
        fp = (float)(sumVec[i] - min) / (float)(max - min);
        CLAMP(fp, 0.0, 1.0);
        temp = (int)((float)typeMult * fp);
        imFinal[i] = temp;
    }
}


template<typename dataT, typename maskT>
void BlurHD<dataT, maskT>::maskFilter3x3(maskT *mask, int maskSize)
{
    int cL = currentLevel;
    int mS = maskSize;
    int temp;
    dataT pix;
    maskT sum = 0;
    maskT maskDiv = 0;

    for (int i = 0; i < mS*mS; i++) {
        maskDiv += mask[i];
    }

#ifdef _OPENMP
    #pragma omp parallel for shared(maskDiv) private(pix, sum, temp)
#endif
    for(int j = 0; j < imHeight[cL]; j++)
    {
        for(int i = 0; i < imWidth[cL]; i++)
        {
            sum = 0;
            for (int k = -mS/2; k <= mS/2; k++)
            {
                for (int p = -mS/2; p <= mS/2; p++)
                {
                    pix = GetPixelClamped(i+k, j+p);
                    sum += (maskT)pix * mask[k+mS/2 + (p+mS/2)*mS];
                }
            }
            temp = (int)(sum / maskDiv);
            CLAMP(temp, 0, 255)
            imTemp[i + j*imWidth[cL]] = temp;
        }
    }

    copyImg(imTemp, imLevels[cL], cL);
}


template<typename dataT, typename maskT>
inline double BlurHD<dataT, maskT>::gauss(double sigma, double x) {
    double expVal = -1 * (pow(x, 2) / pow(2 * sigma, 2));
    double divider = sqrt(2 * M_PI * pow(sigma, 2));
    return (1 / divider) * exp(expVal);
}


template<typename dataT, typename maskT>
void BlurHD<dataT, maskT>::gaussFilter(int maskSize, float sigma)
{

}


template<typename dataT, typename maskT>
void BlurHD<dataT, maskT>::updateParams(int badThres, double borderBright, double gammaCorr, double delta)
{
    blurP.gammaCorr = gammaCorr;
    blurP.delta = delta;
    blurP.borderBright = borderBright;
    blurP.badThres = badThres;
}


// t is a value that goes from 0 to 1 to interpolate in a C1 continuous way across uniformly sampled data points.
// when t is 0, this will return B.  When t is 1, this will return C.  Inbetween values will return an interpolation
// between B and C.  A and B are used to calculate slopes at the edges.
template<typename dataT, typename maskT>
float BlurHD<dataT, maskT>::CubicHermite (float A, float B, float C, float D, float t)
{
    float a = -A / 2.0f + (3.0f*B) / 2.0f - (3.0f*C) / 2.0f + D / 2.0f;
    float b = A - (5.0f*B) / 2.0f + 2.0f*C - D / 2.0f;
    float c = -A / 2.0f + C / 2.0f;
    float d = B;

    return a*t*t*t + b*t*t + c*t + d;
}

template<typename dataT, typename maskT>
float BlurHD<dataT, maskT>::Lerp (float A, float B, float t)
{
    return A * (1.0f - t) + B * t;
}

template<typename dataT, typename maskT>
dataT BlurHD<dataT, maskT>::GetPixelClamped (int x, int y)
{
    int cL = currentLevel;

    CLAMP(x, 0, imWidth[cL] - 1);
    CLAMP(y, 0, imHeight[cL] - 1);
    return imLevels[cL][(y * imWidth[cL]) + x];
}

template<typename dataT, typename maskT>
dataT BlurHD<dataT, maskT>::SampleNearest (float u, float v)
{
    int cL = currentLevel;
    // calculate coordinates
    int xint = int(u * imWidth[cL]);
    int yint = int(v * imHeight[cL]);

    // return pixel
    dataT pixel = GetPixelClamped(xint, yint);
    CLAMP(pixel, 0,  255);
    return pixel;
}

template<typename dataT, typename maskT>
dataT BlurHD<dataT, maskT>::SampleLinear (float u, float v)
{
    int cL = currentLevel;
    // calculate coordinates -> also need to offset by half a pixel to keep image from shifting down and left half a pixel
    float x = (u * imWidth[cL]) - 0.5f;
    int xint = int(x);
    float xfract = x - floor(x);

    float y = (v * imHeight[cL]) - 0.5f;
    int yint = int(y);
    float yfract = y - floor(y);

    // get pixels
    dataT p00 = GetPixelClamped(xint + 0, yint + 0);
    dataT p10 = GetPixelClamped(xint + 1, yint + 0);
    dataT p01 = GetPixelClamped(xint + 0, yint + 1);
    dataT p11 = GetPixelClamped(xint + 1, yint + 1);

    // interpolate bi-linearly!
    float col0 = Lerp(p00, p10, xfract);
    float col1 = Lerp(p01, p11, xfract);
    float value = Lerp(col0, col1, yfract);
    CLAMP(value, 0.0f,  255.0f);
    dataT ret = dataT(value);

    return ret;
}

template<typename dataT, typename maskT>
dataT BlurHD<dataT, maskT>::SampleBicubic (float u, float v)
{
    int cL = currentLevel;
    // calculate coordinates -> also need to offset by half a pixel to keep image from shifting down and left half a pixel
    float x = (u * imWidth[cL]) - 0.5;
    int xint = int(x);
    float xfract = x - floor(x);

    float y = (v * imHeight[cL]) - 0.5;
    int yint = int(y);
    float yfract = y - floor(y);

    // 1st row
    dataT p00 = GetPixelClamped(xint - 1, yint - 1);
    dataT p10 = GetPixelClamped(xint + 0, yint - 1);
    dataT p20 = GetPixelClamped(xint + 1, yint - 1);
    dataT p30 = GetPixelClamped(xint + 2, yint - 1);

    // 2nd row
    dataT p01 = GetPixelClamped(xint - 1, yint + 0);
    dataT p11 = GetPixelClamped(xint + 0, yint + 0);
    dataT p21 = GetPixelClamped(xint + 1, yint + 0);
    dataT p31 = GetPixelClamped(xint + 2, yint + 0);

    // 3rd row
    dataT p02 = GetPixelClamped(xint - 1, yint + 1);
    dataT p12 = GetPixelClamped(xint + 0, yint + 1);
    dataT p22 = GetPixelClamped(xint + 1, yint + 1);
    dataT p32 = GetPixelClamped(xint + 2, yint + 1);

    // 4th row
    dataT p03 = GetPixelClamped(xint - 1, yint + 2);
    dataT p13 = GetPixelClamped(xint + 0, yint + 2);
    dataT p23 = GetPixelClamped(xint + 1, yint + 2);
    dataT p33 = GetPixelClamped(xint + 2, yint + 2);

    // interpolate bi-cubically!
    // Clamp the values since the curve can put the value below 0 or above 255
    float col0 = CubicHermite(p00, p10, p20, p30, xfract);
    float col1 = CubicHermite(p01, p11, p21, p31, xfract);
    float col2 = CubicHermite(p02, p12, p22, p32, xfract);
    float col3 = CubicHermite(p03, p13, p23, p33, xfract);
    float value = CubicHermite(col0, col1, col2, col3, yfract);
    CLAMP(value, 0.0f, 255.0f);
    dataT ret = dataT(value);

    return ret;
}

template<typename dataT, typename maskT>
void BlurHD<dataT, maskT>::ResizeImage (bool scale, int degree)
{
    int sL = currentLevel;
    int eL = (scale) ? currentLevel - 1 : currentLevel + 1;
    int x, y;
    dataT sample;

#ifdef _OPENMP
    #pragma omp parallel for private(x, sample)
#endif
    for (int y = 0; y < imHeight[eL]; ++y)
    {
        float v = float(y) / float(imHeight[eL] - 1);
        for (int x = 0; x < imWidth[eL]; ++x)
        {
            float u = float(x) / float(imWidth[eL] - 1);

            if (degree == 0)
                sample = SampleNearest(u, v);
            else if (degree == 1)
                sample = SampleLinear(u, v);
            else if (degree == 2)
                sample = SampleBicubic(u, v);

            imLevels[eL][x + y*imWidth[eL]] = sample;
        }
    }
    currentLevel = eL;
}



#endif // BLUR_H
