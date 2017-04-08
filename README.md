timelapse-deflicker
===================

Simple perl script for time lapse image deflickering.

Only tested on Linux, but there is a site that reports successful usage on MAC OSX as well (look at the links in the bottom of this readme file).

A sample of how the deflickering looks like: https://www.youtube.com/watch?v=SNfq__chC5M

How to use
===================
You will need to install a few perl packages needed by the script. On ubuntu based systems:

```
apt-get install libfile-type-perl libterm-progressbar-perl perlmagick libimage-exiftool-perl
```

Then, download and save the script in the directory that you store the time lapse images that you want to deflicker. I usually save it in a directory known by the PATH environment variable so that I can access it from anywhere.

Make the script executable (`chmod +x timelapse-deflicker.sh`) and run it.

The script will not *touch* your original images, so don't be afraid to use it. It will just read the images in order to calculate their average luminance value, and it will save the new deflickered images under a *Deflickered* folder located in the current working directory.

Read the next section that has references on complete and more detailed tutorials.

More info and how to use
===================
My original post that explains how to make time lapse videos on linux, and use this script for deflickering, is located at ubuntuforums [here](http://ubuntuforums.org/showthread.php?t=2022316). This post was the original hosting place of the script, since I didn't have a github account back then. I keep on updating this thread from time to time whenever I find some new interesting information that can improve the overall task.

Since 2012 that I first made this post, time lapse making under Linux, and this script, got some more popularity. Now you can find more information about how to create time lapse videos just by using Linux, and some of them use this script for deflickering.

Here is small list with some nice blogs/sites explaining the time lapse process, and how have they used this script for deflickering:

* [Time-lapse Photography with Linux ](http://joegiampaoli.blogspot.no/2015/04/creating-time-lapse-videos-mostly-in.html)
* [Sunflower Timelapse Project](https://tamboekie.github.io/sunflower-timelapse/)
* [How I edited 5100 photos for my last timelapse](https://medium.com/twidi-and-his-camera/how-i-edited-5100-photos-for-my-last-timelapse-20f9ef6fe5db)
* [Command line time-lapse for OSX with de-flicker](https://sites.google.com/a/biodiversityshorts.com/biodiversityshorts/advanced-photography/command-line-tools-scripts-and-processing-for-photography/command-line-time-lapse-for-osx).

[Here](https://www.youtube.com/watch?v=aABIlQokIaM) is a youtube video comparing this deflickering script with the [Magic Lantern](http://www.magiclantern.fm/forum/index.php?topic=2553.0) deflickering script.
