extends ImageFormatLoaderExtension

class_name TIFFImageFormatLoaderExtension

# https://www.fileformat.info/format/tiff/egff.htm
# https://www.itu.int/itudoc/itu-t/com16/tiff-fx/docs/tiff6.pdf

enum DATA_TYPES {
	BYTE      = 1,
	ASCII     = 2,
	SHORT     = 3,
	LONG      = 4,
	RATIONAL  = 5,
	SBYTE     = 6,
	UNDEFINE  = 7,
	SSHORT    = 8,
	SLONG     = 9,
	SRATIONAL = 10,
	FLOAT     = 11,
	DOUBLE    = 12,
}

enum TAG_IDS {
	UNCOMPRESSED					= 1,
	CCITT_1D						= 2,
	CCITT_GROUP_3					= 3,
	CCITT_GROUP_4					= 4,
	LZW								= 5,
	JPEG							= 6,
	NEW_SUB_FILE_TYPE				= 254,
	IMAGE_WIDTH		     			= 256,
	IMAGE_HEIGHT	    			= 257,
	BITS_PER_SAMPLE 				= 258,
	COMPRESSION     				= 259,
	PHOTOMETRIC_INTERPRETATION		= 262,
	CELL_WIDTH						= 264,
	CELL_LENGTH						= 265,
	FILL_ORDER						= 266,
	DOCUMENT_NAME					= 269,
	IMAGE_DESCRIPTION				= 270,
	MAKE							= 271,
	MODEL							= 272,
	STRIP_OFFSETS					= 273,
	ORIENTATION						= 274,
	SAMPLES_PER_PIXEL				= 277,
	ROWS_PER_STRIP					= 278,
	STRIP_BYTE_COUNTS				= 279,
	MIN_SAMPLE_VALUE				= 280,
	MAX_SAMPLE_VALUE				= 281,
	X_RESOLUTION					= 282,
	Y_RESOLUTION					= 283,
	PLANAR_CONFIGURATION			= 284,
	PAGE_NAME						= 285,
	FREE_OFFSETS					= 288,
	FREE_BYTE_COUNTS				= 289,
	GRAY_RESPONSE_UNIT				= 290,
	GRAY_RESPONSE_CURVE				= 291,
	RESOLUTION_UNIT					= 296,
	PAGE_NUMBER						= 297,
	COLOR_RESPONSE_UNIT				= 300,
	COLOR_RESPONSE_CURVE	 		= 301,
	SOFTWARE						= 305,
	DATE_TIME						= 306,
	ARTIST							= 315,
	HOST_COMPUTER					= 316,
	COLOR_MAP						= 320,
	HALFTONE_HINTS					= 321,
	INK_SET							= 332,
	INK_NAMES						= 333,
	NUMBER_OF_INKS					= 334,
	DOT_RANGE						= 336,
	EXTRA_SAMPLES					= 338,
	SAMPLE_FORMAT					= 339,
	JPEG_PROC						= 512,
	JPEG_INTERCHANGE_FORMAT			= 513,
	JPEG_INTERCHANGE_FORMAT_LENGTH	= 514,
	JPEG_RESTART_INTERVAL			= 515,
	JPEG_LOSSLESS_PREDICTORS		= 517,
	JPEG_POINT_TRANSFORMS			= 518,
	JPWG_Q_TABLES					= 519,
	JPEG_DCT_TABLES					= 520,
	JPEG_ACT_TABLES					= 521,
	YCBCR_COEFFICIENTS				= 529,
	YCBCR_SUB_SAMPLING				= 530,
	YCBCR_POSITIONING				= 531,
	REFERENCE_BLACK_WHITE			= 532,
	PACKBITS						= 32773,
	COPYRIGHT						= 33432,
}
func _get_recognized_extensions() -> PackedStringArray:
	return PackedStringArray(["tif", "tiff"])

func _get_value(bytes: PackedByteArray, offset: int, length: int, big_endian: bool):
	var value = 0
	for pos in range(length):
		var mult = pow(256, pos if not big_endian else length - pos - 1)
		value += bytes[offset + pos] * mult
		
	return value
	
func _get_enum_name(enum_: Dictionary, value: int):
	if value not in enum_.values():
		return value
	return enum_.keys()[enum_.values().find(value)]

func _get_tag_value(tag: Dictionary, bytes: PackedByteArray, big_endian: bool):
	var data_offset = tag["data_offset"]
	match tag["data_type"]:
		"BYTE":
			return data_offset
		"ASCII":
			return bytes.slice(data_offset).get_string_from_ascii()
		"SHORT":
			return data_offset
		"LONG":
			return data_offset
		"RATIONAL":
			return _get_value(bytes, data_offset, 4, big_endian) / (1.0 * _get_value(bytes, data_offset + 4, 4, big_endian))
		_:
			return null
		

func _get_tiff_tag(bytes: PackedByteArray, offset: int, big_endian: bool):
	var value = {}
	value["tag_id"] = _get_enum_name(TAG_IDS, _get_value(bytes, offset, 2, big_endian))
	value["data_type"] = _get_enum_name(DATA_TYPES, _get_value(bytes, offset + 2, 2, big_endian))
	value["data_count"] = _get_value(bytes, offset + 4, 4, big_endian)
	value["data_offset"] = _get_value(bytes, offset + 8, 4, big_endian)
	value["data_value"] = _get_tag_value(value, bytes, big_endian)
	return value

func _get_ifd(bytes: PackedByteArray, ifd_offset: int, big_endian: bool):
	var value = {"tag_values": {}}
	value["num_dir_entries"] = _get_value(bytes, ifd_offset, 2, big_endian)
	var tags = []
	for pos in range(value["num_dir_entries"]):
		var tag = _get_tiff_tag(bytes, ifd_offset + 2 + pos * 12, big_endian)
		value["tag_values"][tag["tag_id"]] = tag["data_value"]
		tags.append(tag)
	value["tag_list"] = tags
	value["next_ifd_offset"] = _get_value(bytes, ifd_offset + 2 + len(tags) * 12, 4, big_endian)
	return value

func _downsample(image_data: PackedByteArray, bits_per_pixel: int, big_endian: bool) -> PackedByteArray:
	var byte_array = []
	@warning_ignore("integer_division")
	var bytes_per_pixel = bits_per_pixel / 8
	if bytes_per_pixel == 1:
		return image_data
	@warning_ignore("integer_division")
	var pixel_len = len(image_data) / bytes_per_pixel
	for pixel in range(pixel_len):
		var offset = pixel * bytes_per_pixel
		byte_array.append(image_data[offset] if big_endian else image_data[offset + bytes_per_pixel - 1])
	
	return PackedByteArray(byte_array)

func _load_image(image: Image, fileaccess: FileAccess, _flags: ImageFormatLoader.LoaderFlags, _scale: float) -> Error:
	var file_bytes = FileAccess.get_file_as_bytes(fileaccess.get_path_absolute())
	var header = file_bytes.slice(0,8)
	var identifier = header.slice(0,2)
	assert(identifier[0] == identifier[1])
	assert(identifier[0] == 0x49 or identifier[0] == 0x4D)
	var big_endian = identifier[0] == 0x4D
	var _version = _get_value(header, 2, 2, big_endian)
	var ifd_offset = _get_value(header, 4, 4, big_endian)
	var ifds = []
	while ifd_offset > 0:
		var ifd = _get_ifd(file_bytes, ifd_offset, big_endian)
		ifds.append(ifd)
		ifd_offset = ifd["next_ifd_offset"]
	
	var first_image = ifds[0]
	
	var sample_format = first_image["tag_values"].get("SAMPLE_FORMAT", 1)
	if sample_format != 1:
		printerr("UNSUPPORTED SAMPLE FORMAT: %d" % sample_format)
		return ERR_FILE_UNRECOGNIZED
		
	var compression = first_image["tag_values"].get("COMPRESSION", 1)
	if compression != 1:
		printerr("UNSUPPORTED COMPRESSION: %d" % compression)
		return ERR_FILE_UNRECOGNIZED
	
	var width = first_image["tag_values"]["IMAGE_WIDTH"]
	var height = first_image["tag_values"]["IMAGE_HEIGHT"]
	var bits_per_pixel = first_image["tag_values"]["BITS_PER_SAMPLE"] * first_image["tag_values"]["SAMPLES_PER_PIXEL"]
	var rows_per_strip = first_image["tag_values"].get("ROWS_PER_STRIP", height)
	if rows_per_strip != height:
		printerr("UNSUPPORTED: Does not support complex strip arrangements yet (%d, %d)." % [rows_per_strip, height])
		return ERR_FILE_UNRECOGNIZED
	
	var image_data = file_bytes.slice(first_image["tag_values"]["STRIP_OFFSETS"], first_image["tag_values"]["STRIP_OFFSETS"] + first_image["tag_values"]["STRIP_BYTE_COUNTS"])
	
	image.set_data(width, height, false, Image.FORMAT_L8, _downsample(image_data, bits_per_pixel, big_endian))
	
	return OK
