import 'package:flutter/material.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'app_cached_image.dart';

class PhotoCarousel extends StatefulWidget {
  final List<String> photoUrls;
  final double? height;
  final BorderRadius? borderRadius;

  const PhotoCarousel({
    super.key,
    required this.photoUrls,
    this.height,
    this.borderRadius,
  });

  @override
  State<PhotoCarousel> createState() => _PhotoCarouselState();
}

class _PhotoCarouselState extends State<PhotoCarousel> {
  final _controller = PageController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.photoUrls.isEmpty) {
      return Container(
        height: widget.height ?? 400,
        color: Colors.grey[200],
        child: const Center(
          child: Icon(Icons.person, size: 80, color: Colors.grey),
        ),
      );
    }

    return Stack(
      alignment: Alignment.bottomCenter,
      children: [
        SizedBox(
          height: widget.height ?? 400,
          child: PageView.builder(
            controller: _controller,
            itemCount: widget.photoUrls.length,
            itemBuilder: (context, index) {
              return AppCachedImage(
                imageUrl: widget.photoUrls[index],
                fit: BoxFit.cover,
                borderRadius: widget.borderRadius,
              );
            },
          ),
        ),
        if (widget.photoUrls.length > 1)
          Positioned(
            bottom: 12,
            child: SmoothPageIndicator(
              controller: _controller,
              count: widget.photoUrls.length,
              effect: const WormEffect(
                dotHeight: 8,
                dotWidth: 8,
                activeDotColor: Colors.white,
                dotColor: Colors.white54,
              ),
            ),
          ),
      ],
    );
  }
}
