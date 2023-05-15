#include <fileref.h>
#include <tag.h>
#include <tpropertymap.h>

#include <commentsframe.h>
#include <id3v2frame.h>
#include <id3v2header.h>
#include <id3v2tag.h>
#include <textidentificationframe.h>

#include <asffile.h>
#include <flacfile.h>
#include <mp4file.h>
#include <mpcfile.h>
#include <mpegfile.h>
#include <oggflacfile.h>
#include <speexfile.h>
#include <trueaudiofile.h>
#include <vorbisfile.h>
#include <wavpackfile.h>

#include <cstdint>
#include <cstring>

using namespace std;

extern "C" TagLib::FileRef *taglib_file_new(char *path) { return new TagLib::FileRef(path); }

extern "C" TagLib::Tag *taglib_file_tag(TagLib::FileRef *f) {
  if (!f->isNull() && f->tag()) {
    return f->tag();
  }
  return NULL;
}

extern "C" bool taglib_file_is_valid(TagLib::FileRef *f) {
  if (f->file() == NULL) {
    return false;
  }
  return f->file()->isValid();
}

extern "C" void taglib_file_free(TagLib::FileRef *f) { delete f; }

struct ImageMetadata {
  ImageMetadata(const TagLib::String &m = TagLib::String(),
                const TagLib::ByteVector &d = TagLib::ByteVector()) {
    this->mimetype = strdup(m.toCString(false));
    this->data_length = d.size();
  }
  const char *mimetype;
  uint32_t data_length;
};

struct ImageData {
  ImageData(const TagLib::String &m = TagLib::String(),
            const TagLib::ByteVector &d = TagLib::ByteVector())
      : mimetype(m), picture(d) {}
  TagLib::String mimetype;
  TagLib::ByteVector picture;
};

TagLib::String taglib_mp4_format_to_mimetype(TagLib::MP4::CoverArt::Format format) {
  switch (format) {
  case TagLib::MP4::CoverArt::Format::PNG:
    return "image/png";
  case TagLib::MP4::CoverArt::Format::JPEG:
    return "image/jpeg";
  case TagLib::MP4::CoverArt::Format::BMP:
    return "image/bmp";
  case TagLib::MP4::CoverArt::Format::GIF:
    return "image/gif";
  default:
    return "";
  }
}

ImageData *taglib_get_attached_picture_frame(TagLib::FileRef *f) {
  TagLib::File *fh = f->file();
  if (TagLib::MPEG::File *audioFile = dynamic_cast<TagLib::MPEG::File *>(fh)) {
    TagLib::ID3v2::Tag *tag = audioFile->ID3v2Tag(true);
    TagLib::ID3v2::FrameList frames = tag->frameList("APIC");
    if (frames.isEmpty()) {
      return NULL;
    }

    TagLib::ID3v2::AttachedPictureFrame *frame =
        static_cast<TagLib::ID3v2::AttachedPictureFrame *>(frames.front());

    return new ImageData(frame->mimeType(), frame->picture());
  } else if (TagLib::MP4::File *audioFile = dynamic_cast<TagLib::MP4::File *>(fh)) {
    TagLib::MP4::Tag *tag = audioFile->tag();
    if (!tag->contains("covr")) {
      return NULL;
    }
    TagLib::MP4::CoverArtList art = tag->item("covr").toCoverArtList();
    TagLib::MP4::CoverArt pic = art.front();

    return new ImageData(taglib_mp4_format_to_mimetype(pic.format()), pic.data());
  } else if (TagLib::FLAC::File *audioFile = dynamic_cast<TagLib::FLAC::File *>(fh)) {
    if (audioFile->pictureList().isEmpty()) {
      return NULL;
    }

    TagLib::FLAC::Picture *pic = audioFile->pictureList().front();
    return new ImageData(pic->mimeType(), pic->data());
  } else if (TagLib::Ogg::File *audioFile = dynamic_cast<TagLib::Ogg::File *>(fh)) {
    TagLib::Ogg::XiphComment *tag = dynamic_cast<TagLib::Ogg::XiphComment *>(audioFile->tag());
    if (tag->pictureList().isEmpty()) {
      return NULL;
    }

    TagLib::FLAC::Picture *pic = tag->pictureList().front();
    return new ImageData(pic->mimeType(), pic->data());
  }

  return NULL;
}

extern "C" ImageMetadata *taglib_get_image_md(TagLib::FileRef *f) {
  auto *frame = taglib_get_attached_picture_frame(f);
  if (frame == NULL) {
    return new ImageMetadata();
  }

  auto md = new ImageMetadata(frame->mimetype, frame->picture);
  delete frame;
  return md;
}

extern "C" ssize_t taglib_get_image_buf(TagLib::FileRef *f, char *buf, size_t size) {
  auto *frame = taglib_get_attached_picture_frame(f);
  if (frame == NULL) {
    return -1;
  }

  auto pic = frame->picture;
  auto dsize = pic.size();
  if (dsize <= size) {
    memcpy(buf, pic.data(), dsize);
  }
  delete frame;

  return dsize;
}

extern "C" char **taglib_all_tags_pairs(TagLib::FileRef *f, uint32_t *tagcount) {
  *tagcount = 0;
  if (f == NULL || f->file() == NULL) {
    return NULL;
  }

  TagLib::PropertyMap tags = f->file()->properties();

  // Find how many elements to allocate
  if (tags.size() == 0) {
    return NULL;
  }
  for (TagLib::PropertyMap::ConstIterator i = tags.begin(); i != tags.end(); ++i) {
    for (TagLib::StringList::ConstIterator j = i->second.begin(); j != i->second.end(); ++j) {
      *tagcount += 2;
    }
  }

  char **out = (char **)malloc(sizeof(char *) * *tagcount);

  uint32_t counter = 0;
  for (TagLib::PropertyMap::ConstIterator i = tags.begin(); i != tags.end(); ++i) {
    char *key = strdup(i->first.toCString(true));
    for (TagLib::StringList::ConstIterator j = i->second.begin(); j != i->second.end(); ++j) {
      out[counter] = key;
      out[counter + 1] = strdup(j->toCString(true));
      counter += 2;
    }
  }

  return out;
}

extern "C" bool taglib_has_id3v2(TagLib::FileRef *f) {
  TagLib::File *fh = f->file();
  if (TagLib::MPEG::File *audioFile = dynamic_cast<TagLib::MPEG::File *>(fh)) {
    return audioFile->hasID3v2Tag();
  } else if (TagLib::FLAC::File *audioFile = dynamic_cast<TagLib::FLAC::File *>(fh)) {
    return audioFile->hasID3v2Tag();
  }

  return false;
}

extern "C" char **taglib_id3v2_pairs(TagLib::FileRef *f, uint32_t *tagcount) {
  if (f == NULL || f->file() == NULL) {
    return NULL;
  }

  TagLib::File *fh = f->file();
  TagLib::ID3v2::Tag *id3v2tag = NULL;
  if (TagLib::MPEG::File *audioFile = dynamic_cast<TagLib::MPEG::File *>(fh)) {
    if (audioFile->hasID3v2Tag()) {
      id3v2tag = audioFile->ID3v2Tag();
    }
  } else if (TagLib::FLAC::File *audioFile = dynamic_cast<TagLib::FLAC::File *>(fh)) {
    if (audioFile->hasID3v2Tag()) {
      id3v2tag = audioFile->ID3v2Tag();
    }
  }

  if (id3v2tag == NULL) {
    return NULL;
  }

  for (TagLib::ID3v2::FrameList::ConstIterator it = id3v2tag->frameList().begin();
       it != id3v2tag->frameList().end(); it++) {
    *tagcount += 2;
  }

  char **out = (char **)malloc(sizeof(char *) * *tagcount);

  size_t i = 0;
  for (TagLib::ID3v2::FrameList::ConstIterator it = id3v2tag->frameList().begin();
       it != id3v2tag->frameList().end(); it++) {

    auto frameID = (*it)->frameID();
    char *frameName = strndup(frameID.data(), frameID.size());

    if (auto *comment = dynamic_cast<TagLib::ID3v2::CommentsFrame *>(*it)) {
      if (!comment->description().isEmpty()) {
        const char *key = comment->description().toCString(true);
        size_t nameSize = strlen(frameName) + 1 + strlen(key) + 1;
        out[i] = (char *)malloc(nameSize);
        snprintf(out[i], nameSize, "%s:%s", frameName, key);
        free(frameName);
      } else {
        out[i] = frameName;
      }

      out[i + 1] = strdup((*it)->toString().toCString(true));

    } else if (auto *tif = dynamic_cast<TagLib::ID3v2::UserTextIdentificationFrame *>(*it)) {
      if (!tif->description().isEmpty()) {
        const char *key = tif->description().toCString(true);
        size_t nameSize = strlen(frameName) + 1 + strlen(key) + 1;
        out[i] = (char *)malloc(nameSize);
        snprintf(out[i], nameSize, "%s:%s", frameName, key);
        free(frameName);
      } else {
        out[i] = frameName;
      }

      // The first item is the description, so drop it
      auto l = TagLib::StringList(tif->fieldList());
      for (auto it = l.begin(); it != l.end(); ++it) {
        l.erase(it);
        break;
      };
      out[i + 1] = strdup(l.toString().toCString(true));

    } else {
      out[i] = frameName;
      out[i + 1] = strdup((*it)->toString().toCString(true));
    }

    i += 2;
  }

  return out;
}

extern "C" char *taglib_tag_title(TagLib::Tag *tag) {
  if (!tag->title().isEmpty()) {
    return strdup(tag->title().toCString(true));
  }
  return NULL;
}

extern "C" char *taglib_tag_artist(TagLib::Tag *tag) {
  if (!tag->artist().isEmpty()) {
    return strdup(tag->artist().toCString(true));
  }
  return NULL;
}

extern "C" char *taglib_tag_album(TagLib::Tag *tag) {
  if (!tag->album().isEmpty()) {
    return strdup(tag->album().toCString(true));
  }
  return NULL;
}

extern "C" char *taglib_tag_comment(TagLib::Tag *tag) {
  if (!tag->comment().isEmpty()) {
    return strdup(tag->comment().toCString(true));
  }
  return NULL;
}

extern "C" char *taglib_tag_genre(TagLib::Tag *tag) {
  if (!tag->genre().isEmpty()) {
    return strdup(tag->genre().toCString(true));
  }
  return NULL;
}

extern "C" uint32_t taglib_tag_year(TagLib::Tag *tag) { return tag->year(); }

extern "C" uint32_t taglib_tag_track(TagLib::Tag *tag) { return tag->track(); }

extern "C" uint32_t taglib_file_length(TagLib::FileRef *f) {
  return f->audioProperties()->length();
}
