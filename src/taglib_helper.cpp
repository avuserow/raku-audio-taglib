#include <fileref.h>
#include <tag.h>
#include <tpropertymap.h>

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

#include <cstring>
using namespace std;

extern "C" void* taglib_file_new(char* path) {
    TagLib::FileRef* f = new TagLib::FileRef(path);
    return f;
}

extern "C" void* taglib_file_tag(TagLib::FileRef* f) {
    if (!f->isNull() && f->tag()) {
        return f->tag();
    }
    return NULL;
}

extern "C" bool taglib_file_is_valid(TagLib::FileRef* f) {
    if (f->file() == NULL) {
        return false;
    }
    return f->file()->isValid();
}

extern "C" void taglib_file_free(TagLib::FileRef* f) {
    delete f;
}

/*
void printConcreteFileType(TagLib::FileRef* fr) {
    j
    TagLib::File* fh = fr->file();
    if (TagLib::MPEG::File* cf = dynamic_cast<TagLib::MPEG::File*>(fh)) {
        puts("wow, have a MPEG file");
    } else if (TagLib::Ogg::File* cf = dynamic_cast<TagLib::Ogg::File*>(fh)) {
        puts("wow, have an OGG file");
    } else if (TagLib::FLAC::File* cf = dynamic_cast<TagLib::FLAC::File*>(fh)) {
        puts("wow, have an FLAC file");
    }
}
*/

extern "C" char** taglib_all_tags_pairs(TagLib::FileRef* f, uint32_t* tagcount) {
    *tagcount = 0;
    if (f == NULL || f->file() == NULL) {
        return NULL;
    }

    TagLib::PropertyMap tags = f->file()->properties();

    // Find how many elements to allocate
    if (tags.size() == 0) {
        return NULL;
    }
    for(TagLib::PropertyMap::ConstIterator i = tags.begin(); i != tags.end(); ++i) {
        for(TagLib::StringList::ConstIterator j = i->second.begin(); j != i->second.end(); ++j) {
            *tagcount += 2;
        }
    }

    char** out = (char**) malloc(sizeof(char*) * *tagcount);

    uint32_t counter = 0;
    for(TagLib::PropertyMap::ConstIterator i = tags.begin(); i != tags.end(); ++i) {
        char* key = strdup(i->first.toCString(true));
        for(TagLib::StringList::ConstIterator j = i->second.begin(); j != i->second.end(); ++j) {
            out[counter] = key;
            out[counter+1] = strdup(j->toCString(true));
            counter += 2;
        }
    }

    return out;
}

extern "C" char* taglib_tag_title(TagLib::Tag* tag) {
    if (!tag->title().isEmpty()) {
        return strdup(tag->title().toCString(true));
    }
    return NULL;
}

extern "C" char* taglib_tag_artist(TagLib::Tag* tag) {
    if (!tag->artist().isEmpty()) {
        return strdup(tag->artist().toCString(true));
    }
    return NULL;
}

extern "C" char* taglib_tag_album(TagLib::Tag* tag) {
    if (!tag->album().isEmpty()) {
        return strdup(tag->album().toCString(true));
    }
    return NULL;
}

extern "C" char* taglib_tag_comment(TagLib::Tag* tag) {
    if (!tag->comment().isEmpty()) {
        return strdup(tag->comment().toCString(true));
    }
    return NULL;
}

extern "C" char* taglib_tag_genre(TagLib::Tag* tag) {
    if (!tag->genre().isEmpty()) {
        return strdup(tag->genre().toCString(true));
    }
    return NULL;
}

extern "C" uint32_t taglib_tag_year(TagLib::Tag* tag) {
    return tag->year();
}

extern "C" uint32_t taglib_tag_track(TagLib::Tag* tag) {
    return tag->track();
}

extern "C" uint32_t taglib_file_length(TagLib::FileRef* f) {
    return f->audioProperties()->length();
}
