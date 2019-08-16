//
//  MovieMetal.h
//  VideoMetalTexture
//
//  Created by William Lindmeier on 7/11/17.
//  Modified by JSR on 2019-08-15
//

#pragma once

#include "cinder/Cinder.h"

// TODO: Update with OS X support
#ifdef CINDER_COCOA_TOUCH

#include "metal.h"
#include <memory>

@class MovieMetalImpl;

namespace cinder { namespace mtl {
    
    typedef std::shared_ptr<class MovieMetal> MovieMetalRef;

    class MovieMetal
    {

    public:

		struct Options
		{
			Options() :
			mLoops(true),
            mVolume(0.5)
			{}

		public:

			Options & loops( bool shouldLoop ) { setLoops( shouldLoop ); return *this; };
			void setLoops( bool shouldLoop ) { mLoops = shouldLoop; };
			bool getLoops() const { return mLoops; };
            
            Options & volume( float value ) { setVolume( value ); return *this; };
            void setVolume( float value ) { mVolume = value; };
            float getVolume() const { return mVolume; };

		protected:

			bool mLoops;
            float mVolume;
		};

		static MovieMetalRef create( const ci::fs::path & movieURL, Options options = Options() )
        {
            return MovieMetalRef(new MovieMetal(movieURL, options));
        }
        
        void play( bool seekToZero = false );
        void pause();
        void seekToTime(double secondsOffset);
		void setPlaybackCompleteHandler( std::function<void (MovieMetal *)> handler )
		{ mPlaybackCompleteHandler = handler; }
        double getDuration();
        void setRate(float rate);
        float getRate();
		const Options & getOptions() { return mOptions; }
        
        TextureBufferRef & getTextureLuma();
        TextureBufferRef & getTextureChroma();
        
    protected:
        
        MovieMetal( const ci::fs::path & movieURL, Options options );
        MovieMetalImpl *mVideoDelegate;
		bool mLoops;
		Options mOptions;
		std::function<void (MovieMetal *)> mPlaybackCompleteHandler;

    };
    
}}

#endif
